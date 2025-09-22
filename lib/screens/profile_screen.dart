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
      final response = await http.get(
        Uri.parse('https://viacep.com.br/ws/$cep/json/'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['erro'] == true) {
          setState(() {
            _cepError = 'CEP não encontrado';
          });
          return;
        }

        setState(() {
          _streetController.text = data['logradouro'] ?? '';
          _neighborhoodController.text = data['bairro'] ?? '';
          _cityController.text = data['localidade'] ?? '';
          _stateController.text = data['uf'] ?? '';
        });
      } else {
        setState(() {
          _cepError = 'Erro ao buscar CEP';
        });
      }
    } catch (e) {
      setState(() {
        _cepError = 'Erro ao buscar CEP';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
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

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = widget.authService.currentUser;
      if (user == null) throw ('Usuário não autenticado');

      // Verificar se CPF já está cadastrado por outro usuário
      final isDuplicate = await _isCpfAlreadyRegistered(_cpfController.text);
      if (isDuplicate) {
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

      if (address['cep']!.isEmpty ||
          address['street']!.isEmpty ||
          address['number']!.isEmpty ||
          address['neighborhood']!.isEmpty ||
          address['city']!.isEmpty ||
          address['state']!.isEmpty) {
        throw ('Por favor, preencha todos os campos obrigatórios do endereço');
      }

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
        onTap: onTap,
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
    return Scaffold(
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
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
                    const SizedBox(height: 32),
                    SizedBox(
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
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAddressFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
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
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
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
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
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
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: TextFormField(
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
