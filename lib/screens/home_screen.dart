import 'package:flutter/material.dart';
import 'package:ftw_solucoes/screens/login_screen.dart';
import 'package:ftw_solucoes/screens/settings_screen.dart';
import 'package:ftw_solucoes/services/auth_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ftw_solucoes/screens/profile_screen.dart';
import 'package:ftw_solucoes/screens/my_cars_screen.dart';
import 'package:ftw_solucoes/screens/available_services_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ftw_solucoes/screens/service_history_screen.dart';

class HomeScreen extends StatefulWidget {
  final AuthService authService;

  const HomeScreen({Key? key, required this.authService}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _userName = '';
  String? _photoUrl;
  bool _snackbarShown = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = widget.authService.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        debugPrint('Dados do usuário carregados: $data');

        if (mounted) {
          setState(() {
            _userName = data['name'] ?? '';
            final photoUrl = data['photoUrl'];
            debugPrint('URL da foto encontrada: $photoUrl');

            if (photoUrl != null && photoUrl.toString().isNotEmpty) {
              String cleanUrl = photoUrl.toString().trim();
              // Remover quebras de linha e espaços extras
              cleanUrl = cleanUrl.replaceAll(RegExp(r'[\n\r\s]+'), '');

              try {
                // Verificar se a URL é válida
                final uri = Uri.parse(cleanUrl);
                if (uri.isAbsolute && uri.scheme.startsWith('http')) {
                  _photoUrl = uri.toString();
                  debugPrint('URL da foto validada: $_photoUrl');
                } else {
                  debugPrint('URL inválida: $cleanUrl');
                  _photoUrl = null;
                }
              } catch (e) {
                debugPrint('Erro ao processar URL da foto: $e');
                _photoUrl = null;
              }
            } else {
              debugPrint('URL da foto não encontrada ou vazia');
              _photoUrl = null;
            }
          });
        }
      } else {
        debugPrint('Documento do usuário não encontrado');
      }
    } catch (e) {
      debugPrint('Erro ao carregar dados do usuário: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar dados do usuário: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleLogout() async {
    await widget.authService.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => LoginScreen(authService: widget.authService),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Exibe Snackbar de sucesso se argumento for passado, apenas uma vez
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_snackbarShown) {
        final args = ModalRoute.of(context)?.settings.arguments;
        if (args is String && args == 'pagamento_sucesso') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Pagamento realizado com sucesso!',
                  style: GoogleFonts.poppins()),
              backgroundColor: Colors.green,
            ),
          );
          _snackbarShown = true;
        }
      }
    });
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'FTW Soluções',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(
                _userName,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              accountEmail: Text(
                widget.authService.currentUser?.email ?? '',
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                ),
              ),
              currentAccountPicture: _photoUrl != null
                  ? CircleAvatar(
                      backgroundColor: Colors.white,
                      radius: 30,
                      child: ClipOval(
                        child: Image.network(
                          _photoUrl!,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          cacheWidth: 120,
                          cacheHeight: 120,
                          headers: const {
                            'Cache-Control': 'no-cache',
                            'Pragma': 'no-cache',
                            'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8',
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              width: 60,
                              height: 60,
                              color: Colors.grey[200],
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes !=
                                          null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            debugPrint('Erro ao carregar imagem: $error');
                            debugPrint('Stack trace: $stackTrace');
                            return Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  _userName.isNotEmpty
                                      ? _userName[0].toUpperCase()
                                      : '?',
                                  style: GoogleFonts.poppins(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    )
                  : CircleAvatar(
                      backgroundColor: Colors.white,
                      radius: 30,
                      child: Text(
                        _userName.isNotEmpty ? _userName[0].toUpperCase() : '?',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Perfil'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ProfileScreen(authService: widget.authService),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.directions_car),
              title: Text(
                'Meus Carros',
                style: GoogleFonts.poppins(),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MyCarsScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: Text(
                'Configurações',
                style: GoogleFonts.poppins(),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            SettingsScreen(authService: widget.authService)));
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: Text(
                'Sair',
                style: GoogleFonts.poppins(),
              ),
              onTap: _handleLogout,
            ),
          ],
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    'FTW',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Bem-vindo à FTW Soluções',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SobreScreen(),
                      ),
                    );
                  },
                  child: Text(
                    'Conheça a FTW!',
                    style: GoogleFonts.poppins(
                      color: Colors.blueAccent,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      decoration: TextDecoration.underline,
                      letterSpacing: 1.2,
                      shadows: [
                        Shadow(
                          color: Colors.blue.withOpacity(0.2),
                          offset: Offset(0, 2),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AvailableServicesScreen(
                          authService: widget.authService),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                icon: const Icon(Icons.build_outlined),
                label: Text(
                  'Conheça os Serviços',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ServiceHistoryScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                icon: const Icon(Icons.history),
                label: Text(
                  'Meus Agendamentos',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchAppointments() async {
    final user = widget.authService.currentUser;
    if (user == null) return [];
    final querySnapshot = await FirebaseFirestore.instance
        .collection('appointments')
        .where('userId', isEqualTo: user.uid)
        .get();
    final appointments = querySnapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
    appointments.sort((a, b) {
      final dateA = (a['dateTime'] as Timestamp).toDate();
      final dateB = (b['dateTime'] as Timestamp).toDate();
      return dateB.compareTo(dateA);
    });
    return appointments;
  }

  String _getServiceDuration(String service) {
    // Exemplo de tempos para cada serviço
    switch (service.toLowerCase()) {
      case 'lavagem suv':
      case 'lavagem carro comum':
        return '1h';
      case 'lavagem caminhonete':
        return '1h 30min';
      case 'leva e traz':
        return '30min';
      case 'espelhamento':
        return '2h';
      case 'polimento':
        return '2h';
      case 'higienização':
        return '1h 30min';
      case 'hidratação de couro':
        return '1h';
      case 'enceramento':
        return '1h';
      case 'cristalização de faróis':
        return '40min';
      case 'remoção de chuva ácida':
        return '1h';
      case 'lavagem do motor':
        return '40min';
      case 'revitalização de para-choques e plásticos':
        return '50min';
      case 'higienização interna com extratora':
        return '1h 20min';
      case 'micropintura':
        return '1h';
      case 'lavagem por baixo do veículo':
        return '1h';
      default:
        return '1h';
    }
  }
}

class SobreScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sobre a FTW', style: GoogleFonts.poppins()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Apresentação Institucional – FTW Soluções Automotivas',
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Desde 2013, a FTW Soluções Automotivas atua com excelência no segmento de lavagem e estética automotiva em Porto Alegre, oferecendo serviços de alta qualidade para um público exigente e apaixonado por carros.\n'
              'Nossa missão é entregar não apenas veículos limpos, mas experiências marcantes, através de um cuidado minucioso com cada detalhe. Trabalhamos com produtos de primeira linha e técnicas especializadas, garantindo um resultado superior e duradouro.\n'
              'Com mais de uma década de história, construímos uma reputação sólida baseada na confiança, no comprometimento e no padrão de qualidade FTW, que pode ser visto no brilho de cada carro que passa por nossas mãos.\n'
              'Seja para proteger, restaurar ou simplesmente valorizar a aparência do seu veículo, a FTW é a escolha certa para quem trata o carro como uma verdadeira paixão.',
              style: GoogleFonts.poppins(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
