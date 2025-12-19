import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../screens/login_screen.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../utils/error_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:ftw_solucoes/utils/validation_utils.dart';

class ProfileScreen extends StatefulWidget {
  final AuthService authService;

  const ProfileScreen({Key? key, required this.authService}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = false;
  bool _isLoggingOut = false;
  String? _currentPhotoUrl;
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _nameFieldKey = GlobalKey<FormFieldState<String>>();
  final _cpfFieldKey = GlobalKey<FormFieldState<String>>();
  final _phoneFieldKey = GlobalKey<FormFieldState<String>>();
  final _cepFieldKey = GlobalKey<FormFieldState<String>>();
  final _streetFieldKey = GlobalKey<FormFieldState<String>>();
  final _numberFieldKey = GlobalKey<FormFieldState<String>>();
  final _neighborhoodFieldKey = GlobalKey<FormFieldState<String>>();
  final _cityFieldKey = GlobalKey<FormFieldState<String>>();
  final _stateFieldKey = GlobalKey<FormFieldState<String>>();
  final _nameController = TextEditingController();
  final _cpfController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cepController = TextEditingController();
  final _streetController = TextEditingController();
  final _numberController = TextEditingController();
  final _complementController = TextEditingController();
  final _neighborhoodController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  StreamSubscription<User?>? _authStateSubscription;
  bool _isImageLoading = false;
  String? _cepError;
  final _cepFocusNode = FocusNode();

  final _cpfFormatter = MaskTextInputFormatter(
    mask: '###.###.###-##',
    filter: {"#": RegExp(r'[0-9]')},
  );

  // Funções de validação usando ValidationUtils
  bool _isValidCpf(String cpf) => ValidationUtils.isValidCpf(cpf);
  bool _isValidPhone(String phone) => ValidationUtils.isValidPhone(phone);
  bool _isValidName(String name) => ValidationUtils.isValidName(name);
  bool _isValidCep(String cep) => ValidationUtils.isValidCep(cep);

  // Função para verificar se CPF já está cadastrado
  Future<bool> _isCpfAlreadyRegistered(String cpf) async {
    try {
      final cleanCpf = cpf.replaceAll(RegExp(r'[^\d]'), '');
      if (cleanCpf.length != 11) return false;

      final user = widget.authService.currentUser;
      if (user == null) return false;

      // Buscar usuários com o mesmo CPF, exceto o usuário atual
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('cpf', isEqualTo: _cpfController.text)
          .get();

      // Se encontrou algum documento e não é o usuário atual
      for (var doc in querySnapshot.docs) {
        if (doc.id != user.uid) {
          return true; // CPF já está cadastrado por outro usuário
        }
      }

      return false; // CPF não está cadastrado ou é do usuário atual
    } catch (e) {
      debugPrint('Erro ao verificar CPF duplicado: $e');
      return false; // Em caso de erro, não bloquear o cadastro
    }
  }

  final _phoneFormatter = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {"#": RegExp(r'[0-9]')},
  );

  final _cepFormatter = MaskTextInputFormatter(
    mask: '#####-###',
    filter: {"#": RegExp(r'[0-9]')},
  );

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadCurrentPhoto();
    _cepFocusNode.addListener(_onCepFocusChanged);
    _authStateSubscription =
        FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (!mounted) return;
      if (user == null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => LoginScreen(authService: widget.authService),
          ),
          (route) => false,
        );
      }
    });
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final user = widget.authService.currentUser;
      if (user != null) {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final userData = doc.data()!;
          setState(() {
            _nameController.text = userData['name'] ?? '';
            _cpfController.text = userData['cpf'] ?? '';
            _phoneController.text = userData['phone'] ?? '';

            final address = userData['address'] as Map<String, dynamic>?;
            if (address != null) {
              _cepController.text = address['cep'] ?? '';
              _streetController.text = address['street'] ?? '';
              _numberController.text = address['number'] ?? '';
              _complementController.text = address['complement'] ?? '';
              _neighborhoodController.text = address['neighborhood'] ?? '';
              _cityController.text = address['city'] ?? '';
              _stateController.text = address['state'] ?? '';
            }
          });
        } else {
          await _firestore.collection('users').doc(user.uid).set({
            'email': user.email,
            'createdAt': FieldValue.serverTimestamp(),
          });
          setState(() {});
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar dados: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadCurrentPhoto() async {
    try {
      setState(() => _isImageLoading = true);
      final user = widget.authService.currentUser;
      if (user != null) {
        final userData =
            await _firestore.collection('users').doc(user.uid).get();

        if (userData.exists && userData.data()!.containsKey('photoUrl')) {
          final photoUrl = userData.data()!['photoUrl'] as String;
          if (photoUrl.isNotEmpty) {
            // Verifica se a URL é válida
            try {
              final response = await Dio().head(photoUrl);
              if (response.statusCode == 200) {
                setState(() {
                  _currentPhotoUrl = photoUrl;
                });
              } else {
                debugPrint('URL da imagem inválida: $photoUrl');
                setState(() {
                  _currentPhotoUrl = null;
                });
              }
            } catch (e) {
              debugPrint('Erro ao verificar URL da imagem: $e');
              setState(() {
                _currentPhotoUrl = null;
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar foto de perfil: $e');
      setState(() {
        _currentPhotoUrl = null;
      });
    } finally {
      if (mounted) {
        setState(() => _isImageLoading = false);
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final user = widget.authService.currentUser;
      if (user == null) {
        throw ('Usuário não autenticado');
      }

      if (_storage.app.options.projectId.isEmpty) {
        throw ('Firebase Storage não inicializado corretamente');
      }

      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _isImageLoading = true;
        });

        try {
          final storageRef =
              _storage.ref().child('profile_photos/${user.uid}.jpg');

          UploadTask uploadTask;
          if (kIsWeb) {
            final bytes = await pickedFile.readAsBytes();
            final metadata = SettableMetadata(
              contentType: 'image/jpeg',
              customMetadata: {
                'userId': user.uid,
                'uploadedAt': DateTime.now().toIso8601String(),
              },
            );
            uploadTask = storageRef.putData(bytes, metadata);
          } else {
            final file = File(pickedFile.path);
            final metadata = SettableMetadata(
              contentType: 'image/jpeg',
              customMetadata: {
                'userId': user.uid,
                'uploadedAt': DateTime.now().toIso8601String(),
              },
            );
            uploadTask = storageRef.putFile(file, metadata);
          }

          final snapshot = await uploadTask;

          final downloadUrl = await snapshot.ref.getDownloadURL();

          await _firestore.collection('users').doc(user.uid).update({
            'photoUrl': downloadUrl,
            'lastPhotoUpdate': FieldValue.serverTimestamp(),
          });

          if (mounted) {
            setState(() {
              _currentPhotoUrl = downloadUrl;
              _isImageLoading = false;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Foto de perfil atualizada com sucesso!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          debugPrint('Erro ao processar imagem: $e');
          if (mounted) {
            setState(() {
              _isImageLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erro ao processar imagem. Tente novamente.'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Erro ao selecionar imagem: $e');
      if (mounted) {
        setState(() {
          _isImageLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao selecionar imagem. Tente novamente.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _searchCep() async {
    final cep = _cepController.text.replaceAll(RegExp(r'[^\d]'), '');
    if (cep.length != 8) return;

    setState(() {
      _isLoading = true;
      _cepError = null;
    });

    try {
      final response = await http
          .get(
            Uri.parse('https://viacep.com.br/ws/$cep/json/'),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['erro'] == true) {
          if (mounted) {
            setState(() {
              _cepError = 'CEP não encontrado';
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _streetController.text = data['logradouro'] ?? '';
              _neighborhoodController.text = data['bairro'] ?? '';
              _cityController.text = data['localidade'] ?? '';
              _stateController.text = data['uf'] ?? '';
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _cepError = 'Erro ao buscar CEP';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cepError = 'Erro ao buscar CEP';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onCepChanged(String value) {
    setState(() {
      _cepError = null;
    });
  }

  void _onCepEditingComplete() {
    final cep = _cepController.text.replaceAll(RegExp(r'[^\d]'), '');
    if (cep.length == 8) {
      _searchCep();
    }
  }

  void _onCepFocusChanged() {
    if (!_cepFocusNode.hasFocus) {
      // Quando o campo perde o foco, verificar se o CEP é válido e buscar
      final cep = _cepController.text.replaceAll(RegExp(r'[^\d]'), '');
      if (cep.length == 8) {
        _searchCep();
      }
    }
  }

  void _scrollToFirstInvalidField() {
    final ordered = <GlobalKey<FormFieldState<String>>>[
      _nameFieldKey,
      _cpfFieldKey,
      _phoneFieldKey,
      _cepFieldKey,
      _streetFieldKey,
      _numberFieldKey,
      _neighborhoodFieldKey,
      _cityFieldKey,
      _stateFieldKey,
    ];

    for (final key in ordered) {
      final hasError = key.currentState?.hasError ?? false;
      final isCepKey = identical(key, _cepFieldKey);
      final cepHasExternalError = isCepKey && _cepError != null;
      if (!hasError && !cepHasExternalError) continue;

      final ctx = key.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          alignment: 0.15,
        );
      }
      break;
    }
  }

  void _ensureFieldVisible(GlobalKey<FormFieldState<String>> key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      alignment: 0.20,
    );
  }

  Future<void> _saveProfile() async {
    // Fechar teclado ao clicar em "Salvar Alterações"
    FocusManager.instance.primaryFocus?.unfocus();

    final isValid = _formKey.currentState!.validate();
    if (!isValid) {
      _scrollToFirstInvalidField();
      return;
    }

    // Se o CEP foi buscado e deu erro (ex.: "CEP não encontrado"), não salvar.
    if (_cepError != null) {
      _showErrorMessage(_cepError!);
      _scrollToFirstInvalidField();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = widget.authService.currentUser;
      if (user == null) throw ('Usuário não autenticado');

      // Verificar se CPF já está cadastrado por outro usuário
      final isDuplicate = await _isCpfAlreadyRegistered(_cpfController.text);
      if (isDuplicate) {
        _scrollToFirstInvalidField();
        throw ('CPF já está cadastrado no sistema');
      }

      // Preparar dados do endereço
      final address = {
        'cep': _cepController.text,
        'street': _streetController.text,
        'number': _numberController.text,
        'complement': _complementController.text,
        'neighborhood': _neighborhoodController.text,
        'city': _cityController.text,
        'state': _stateController.text,
      };

      // Atualizar dados no Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'name': _nameController.text,
        'cpf': _cpfController.text,
        'phone': _phoneController.text,
        'address': address,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Atualizar nome no Firebase Auth
      await user.updateDisplayName(_nameController.text);

      setState(() {
        _showSuccessMessage('Perfil atualizado com sucesso!');
      });
    } catch (e) {
      _showErrorMessage(ErrorHandler.getFriendlyErrorMessage(e));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSuccessMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    GlobalKey<FormFieldState<String>>? fieldKey,
    String? hint,
    TextInputFormatter? formatter,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool readOnly = false,
    VoidCallback? onTap,
    void Function(String)? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        key: fieldKey,
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(),
          hintText: hint,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        style: GoogleFonts.poppins(),
        keyboardType: keyboardType,
        inputFormatters: formatter != null ? [formatter] : null,
        validator: validator ??
            (value) {
              if (value == null || value.isEmpty) {
                return 'Campo obrigatório';
              }
              return null;
            },
        readOnly: readOnly,
        onTap: () {
          if (fieldKey != null) {
            _ensureFieldVisible(fieldKey);
          }
          onTap?.call();
        },
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildProfileImage() {
    return GestureDetector(
      onTap: _isLoading ? null : _pickImage,
      child: Stack(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: Colors.grey[300],
            child: _isImageLoading
                ? const CircularProgressIndicator()
                : _currentPhotoUrl != null
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: _currentPhotoUrl!,
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(),
                          ),
                          errorWidget: (context, url, error) => Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.person, size: 40),
                              const SizedBox(height: 4),
                              Text(
                                'Erro ao carregar',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : const Icon(Icons.person, size: 60),
          ),
          if (!_isLoading && !_isImageLoading)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    _cepFocusNode.dispose();
    _scrollController.dispose();
    _nameController.dispose();
    _cpfController.dispose();
    _phoneController.dispose();
    _cepController.dispose();
    _streetController.dispose();
    _numberController.dispose();
    _complementController.dispose();
    _neighborhoodController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    // Espaço para o botão fixo + respiro, para não cobrir campos quando o teclado abrir.
    const bottomBarHeight = 56.0;
    const bottomBarPadding = 16.0 + 16.0; // top + bottom do container
    final scrollBottomPadding = 24.0 + bottomBarHeight + bottomBarPadding + bottomInset;

    return Scaffold(
      // Evita "subir a tela toda" quando o teclado abre; o scroll/padding cuida do ajuste.
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(
          'Meu Perfil',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: _isLoggingOut
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.logout),
            onPressed: _isLoggingOut ? null : _handleLogout,
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.only(
                        left: 24,
                        right: 24,
                        top: 24,
                        bottom: scrollBottomPadding,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: _buildProfileImage(),
                            ),
                            const SizedBox(height: 32),
                            Text(
                              'Informações Pessoais',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _nameController,
                              label: 'Nome Completo',
                              fieldKey: _nameFieldKey,
                              keyboardType: TextInputType.name,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Por favor, informe seu nome completo';
                                }
                                if (!_isValidName(value)) {
                                  return 'Nome deve ter pelo menos 2 palavras e apenas letras';
                                }
                                return null;
                              },
                            ),
                            _buildTextField(
                              controller: _cpfController,
                              label: 'CPF',
                              fieldKey: _cpfFieldKey,
                              formatter: _cpfFormatter,
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Por favor, informe seu CPF';
                                }
                                if (!_isValidCpf(value)) {
                                  return 'CPF inválido';
                                }
                                return null;
                              },
                            ),
                            _buildTextField(
                              controller: _phoneController,
                              label: 'Telefone',
                              fieldKey: _phoneFieldKey,
                              formatter: _phoneFormatter,
                              keyboardType: TextInputType.phone,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Por favor, informe seu telefone';
                                }
                                if (!_isValidPhone(value)) {
                                  return 'Telefone inválido';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Endereço',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildAddressFields(),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, -5),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text(
                                  'Salvar Alterações',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildAddressFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          key: _cepFieldKey,
          controller: _cepController,
          decoration: InputDecoration(
            labelText: 'CEP',
            hintText: '00000-000',
            errorText: _cepError,
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            _cepFormatter,
          ],
          onChanged: _onCepChanged,
          onEditingComplete: _onCepEditingComplete,
          focusNode: _cepFocusNode,
          onTap: () => _ensureFieldVisible(_cepFieldKey),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Por favor, informe o CEP';
            }
            if (!_isValidCep(value)) {
              return 'CEP inválido';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          key: _streetFieldKey,
          controller: _streetController,
          decoration: const InputDecoration(
            labelText: 'Rua',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Por favor, informe a rua';
            }
            if (!ValidationUtils.isValidTextOnly(value)) {
              return 'Rua não deve conter números';
            }
            return null;
          },
          onTap: () => _ensureFieldVisible(_streetFieldKey),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                key: _numberFieldKey,
                controller: _numberController,
                decoration: const InputDecoration(
                  labelText: 'Número',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, informe o número';
                  }
                  if (!ValidationUtils.isValidNumber(value)) {
                    return 'Número deve conter apenas dígitos';
                  }
                  return null;
                },
                onTap: () => _ensureFieldVisible(_numberFieldKey),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _complementController,
                decoration: const InputDecoration(
                  labelText: 'Complemento',
                  hintText: 'Apto, Casa, etc.',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          key: _neighborhoodFieldKey,
          controller: _neighborhoodController,
          decoration: const InputDecoration(
            labelText: 'Bairro',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Por favor, informe o bairro';
            }
            if (!ValidationUtils.isValidTextOnly(value)) {
              return 'Bairro não deve conter números';
            }
            return null;
          },
          onTap: () => _ensureFieldVisible(_neighborhoodFieldKey),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                key: _cityFieldKey,
                controller: _cityController,
                decoration: const InputDecoration(
                  labelText: 'Cidade',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, informe a cidade';
                  }
                  if (!ValidationUtils.isValidTextOnly(value)) {
                    return 'Cidade não deve conter números';
                  }
                  return null;
                },
                onTap: () => _ensureFieldVisible(_cityFieldKey),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: TextFormField(
                key: _stateFieldKey,
                controller: _stateController,
                decoration: const InputDecoration(
                  labelText: 'Estado',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, informe o estado';
                  }
                  if (!ValidationUtils.isValidState(value)) {
                    return 'Estado deve ter 2 letras (ex: SP, RJ)';
                  }
                  return null;
                },
                onTap: () => _ensureFieldVisible(_stateFieldKey),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _handleLogout() async {
    if (_isLoggingOut) return;

    setState(() {
      _isLoggingOut = true;
    });

    try {
      await _authStateSubscription?.cancel();
      await widget.authService.signOut();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => LoginScreen(authService: widget.authService),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHandler.getFriendlyErrorMessage(e)),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
        });
      }
    }
  }
}
