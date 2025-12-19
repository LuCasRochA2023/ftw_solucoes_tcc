const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");
const { onDocumentUpdated } = require("firebase-functions/v2/firestore");

admin.initializeApp();

const db = admin.firestore();
const { FieldValue } = admin.firestore;

function toNumber(value) {
  if (typeof value === "number") return value;
  if (typeof value === "string") {
    const n = Number(value.replace(",", "."));
    return Number.isFinite(n) ? n : null;
  }
  return null;
}

exports.refundOnCancellationFinalized = onDocumentUpdated(
  "appointments/{appointmentId}",
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!before || !after) return;

    const beforeStatus = before.status;
    const afterStatus = after.status;

    // Só atuar na transição: solicitado cancelamento -> cancelado
    if (beforeStatus !== "cancellation_requested" || afterStatus !== "cancelled") {
      return;
    }

    const appointmentId = event.params.appointmentId;
    const userId = after.userId;
    if (!userId) {
      logger.warn("refundOnCancellationFinalized: appointment sem userId", {
        appointmentId,
      });
      return;
    }

    const appointmentRef = event.data.after.ref;
    const userRef = db.collection("users").doc(userId);

    // Buscar pagamentos "paid" vinculados ao agendamento (fora da transação).
    const paymentsSnap = await db
      .collection("payments")
      .where("appointmentId", "==", appointmentId)
      .where("status", "==", "paid")
      .get();

    const serviceTitle =
      paymentsSnap.docs[0]?.data()?.serviceTitle ||
      (Array.isArray(after.services) && after.services[0]?.title) ||
      after.service ||
      "Serviço";

    const paymentMethod = paymentsSnap.docs[0]?.data()?.paymentMethod || null;

    let totalRefund = 0;
    const payments = paymentsSnap.docs.map((d) => ({ ref: d.ref, data: d.data() }));
    for (const p of payments) {
      const amount = toNumber(p.data.amount);
      if (amount && amount > 0) totalRefund += amount;

      // Pagamento misto: incluir o saldo usado (carteira) se estiver registrado.
      const balanceUsed = toNumber(p.data.balanceUsed);
      if (balanceUsed && balanceUsed > 0) totalRefund += balanceUsed;
    }

    // Se não vieram payments, ou se não veio amount/balanceUsed, tenta no appointment (valor total do serviço).
    if (totalRefund <= 0) {
      const fallback = toNumber(after.amount);
      if (fallback && fallback > 0) totalRefund = fallback;
    }

    if (totalRefund <= 0) {
      logger.warn("refundOnCancellationFinalized: valor de devolução inválido", {
        appointmentId,
        userId,
        totalRefund,
      });
      return;
    }

    await db.runTransaction(async (tx) => {
      // Idempotência: se já processou reembolso para esse agendamento, não repetir.
      const appointmentDoc = await tx.get(appointmentRef);
      if (appointmentDoc.get("refundProcessedAt")) {
        logger.info("refundOnCancellationFinalized: reembolso já processado", {
          appointmentId,
        });
        return;
      }

      const userDoc = await tx.get(userRef);
      const currentBalance = toNumber(userDoc.get("balance")) || 0;
      const newBalance = currentBalance + totalRefund;

      tx.update(userRef, { balance: newBalance });

      // Registrar transação de crédito (devolução)
      const transactionRef = db.collection("transactions").doc();
      tx.set(transactionRef, {
        userId,
        amount: totalRefund,
        type: "credit",
        description: `Devolução - Cancelamento - ${serviceTitle}`,
        appointmentId,
        paymentMethod,
        createdAt: FieldValue.serverTimestamp(),
      });

      // Marcar payments como refunded
      for (const p of payments) {
        tx.update(p.ref, {
          status: "refunded",
          refundedAt: FieldValue.serverTimestamp(),
        });
      }

      // Marcar no agendamento que o reembolso já foi processado
      tx.update(appointmentRef, {
        refundProcessedAt: FieldValue.serverTimestamp(),
        refundedAmount: totalRefund,
      });
    });
  }
);


