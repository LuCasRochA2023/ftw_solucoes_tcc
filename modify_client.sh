#!/bin/bash

echo "🔧 Aplicando modificações no software do cliente..."

# Backup
cp lib/screens/schedule_service_screen.dart lib/screens/schedule_service_screen.dart.backup

# 1. Modificar initState
echo "1. Modificando initState..."
sed -i '' 's/void initState() {/void initState() {\n    _initializeAsync();/' lib/screens/schedule_service_screen.dart

# 2. Adicionar método _initializeAsync
echo "2. Adicionando método _initializeAsync..."
sed -i '' '/void initState() {/a\
  void _initializeAsync() async {\
    _serviceTitles = widget.services.map((s) => s['\''title'\'']).join('\'', '\'');\
    _mainColor = widget.services.first['\''color'\''] ?? Colors.blue;\
    _mainIcon = widget.services.first['\''icon'\''] ?? Icons.build;\
    await _initializeDateFormatting();\
    await _generateTimeSlots();\
    _loadBookedTimeSlots();\
    _loadUserCars();\
  }' lib/screens/schedule_service_screen.dart

# 3. Modificar _generateTimeSlots para ser assíncrono
echo "3. Modificando _generateTimeSlots..."
sed -i '' 's/void _generateTimeSlots() {/Future<void> _generateTimeSlots() async {/' lib/screens/schedule_service_screen.dart

# 4. Substituir conteúdo da função _generateTimeSlots
echo "4. Substituindo conteúdo da função _generateTimeSlots..."
awk '
/void _generateTimeSlots\(\) {/ || /Future<void> _generateTimeSlots\(\) async {/ {
  print "  Future<void> _generateTimeSlots() async {";
  print "    _timeSlots.clear();";
  print "    try {";
  print "      // Buscar horários disponíveis do Firebase";
  print "      final snapshot = await _firestore";
  print "          .collection('\''disponibilidade_clientes'\'')";
  print "          .where('\''isAvailableForClients'\'', isEqualTo: true)";
  print "          .get();";
  print "";
  print "      final Set<String> availableSlots = {};";
  print "      for (var doc in snapshot.docs) {";
  print "        final data = doc.data();";
  print "        final date = data['\''date'\''] as String;";
  print "        final startTime = data['\''startTime'\''] as String;";
  print "        final endTime = data['\''endTime'\''] as String;";
  print "";
  print "        // Verificar se é para a data selecionada";
  print "        final selectedDateStr = '\''${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '\''0'\'')}-${_selectedDate.day.toString().padLeft(2, '\''0'\'')}'\'';";
  print "        if (date == selectedDateStr) {";
  print "          availableSlots.add(startTime);";
  print "        }";
  print "      }";
  print "";
  print "      // Adicionar horários disponíveis";
  print "      _timeSlots.addAll(availableSlots.toList());";
  print "      _timeSlots.sort();";
  print "    } catch (e) {";
  print "      debugPrint('\''Erro ao carregar horários: $e'\'');";
  print "      // Fallback: horários padrão se houver erro";
  print "      final startTime = DateTime(2024, 1, 1, 8, 0);";
  print "      final endTime = DateTime(2024, 1, 1, 17, 0);";
  print "      const step = Duration(minutes: 30);";
  print "      const block = Duration(minutes: 120);";
  print "";
  print "      DateTime currentSlot = startTime;";
  print "      while (currentSlot.add(block).isBefore(endTime.add(step)) ||";
  print "          currentSlot.add(block).isAtSameMomentAs(endTime)) {";
  print "        _timeSlots.add(DateFormat('\''HH:mm'\'').format(currentSlot));";
  print "        currentSlot = currentSlot.add(step);";
  print "      }";
  print "    }";
  print "  }";
  in_function = 1;
  next;
}
in_function && /^  }/ {
  in_function = 0;
  next;
}
in_function {
  next;
}
{ print }
' lib/screens/schedule_service_screen.dart > temp_file.dart
mv temp_file.dart lib/screens/schedule_service_screen.dart

# 5. Adicionar método _onDateChanged
echo "5. Adicionando método _onDateChanged..."
sed -i '' '/Future<void> _generateTimeSlots() async {/,/}/a\
\
  Future<void> _onDateChanged(DateTime newDate) async {\
    setState(() {\
      _selectedDate = newDate;\
      _selectedTime = null; // Limpar horário selecionado\
    });\
    await _generateTimeSlots(); // Recarregar horários para nova data\
  }' lib/screens/schedule_service_screen.dart

# 6. Modificar _selectDate para usar _onDateChanged
echo "6. Modificando _selectDate..."
sed -i '' 's/if (picked != null && picked != _selectedDate) {/if (picked != null && picked != _selectedDate) {\n      await _onDateChanged(picked);/' lib/screens/schedule_service_screen.dart

# 7. Remover linhas antigas do _selectDate
echo "7. Removendo linhas antigas..."
sed -i '' '/setState(() {/,/});/d' lib/screens/schedule_service_screen.dart
sed -i '' '/_loadBookedTimeSlots();/d' lib/screens/schedule_service_screen.dart

echo "✅ Modificações aplicadas com sucesso!"
echo "🔍 Verificando sintaxe..."
flutter analyze lib/screens/schedule_service_screen.dart

if [ $? -eq 0 ]; then
  echo "✅ Arquivo está sintaticamente correto!"
else
  echo "❌ Erros encontrados. Restaurando backup..."
  cp lib/screens/schedule_service_screen.dart.backup lib/screens/schedule_service_screen.dart
  echo "📋 Use as instruções manuais em MODIFICACOES_CLIENTE.md"
fi
