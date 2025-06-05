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

class ProfileScreen extends StatefulWidget {
  final AuthService authService;

  const ProfileScreen({Key? key, required this.authService}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
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
  Map<String, dynamic>? _userData;
  StreamSubscription<User?>? _authStateSubscription;
  bool _isEditing = false;
  bool _isImageLoading = false;

  final _cpfFormatter = MaskTextInputFormatter(
    mask: '###.###.###-##',
    filter: {"#": RegExp(r'[0-9]')},
  );

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
          setState(() {
            _userData = doc.data();
            _nameController.text = _userData?['name'] ?? '';
            _cpfController.text = _userData?['cpf'] ?? '';
            _phoneController.text = _userData?['phone'] ?? '';
            _cepController.text = _userData?['cep'] ?? '';
            _streetController.text = _userData?['street'] ?? '';
            _numberController.text = _userData?['number'] ?? '';
            _complementController.text = _userData?['complement'] ?? '';
            _neighborhoodController.text = _userData?['neighborhood'] ?? '';
            _cityController.text = _userData?['city'] ?? '';
            _stateController.text = _userData?['state'] ?? '';
          });
        } else {
          await _firestore.collection('users').doc(user.uid).set({
            'email': user.email,
            'createdAt': FieldValue.serverTimestamp(),
          });
          setState(() {
            _userData = {
              'email': user.email,
            };
          });
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
      // Verify authentication state first
      final user = widget.authService.currentUser;
      if (user == null) {
        throw Exception('Usuário não autenticado');
      }

      // Verify Firebase Storage instance
      if (_storage.app.options.projectId.isEmpty) {
        throw Exception('Firebase Storage não inicializado corretamente');
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
          // Create a reference to the storage location
          final storageRef =
              _storage.ref().child('profile_photos/${user.uid}.jpg');

          // Handle file upload differently for web and mobile
          UploadTask uploadTask;
          if (kIsWeb) {
            // For web platform
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
            // For mobile platforms
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

          // Wait for the upload to complete
          final snapshot = await uploadTask;

          // Get the download URL
          final downloadUrl = await snapshot.ref.getDownloadURL();

          // Update the user's profile in Firestore
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
                content: Text('Erro ao processar imagem: ${e.toString()}'),
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
            content: Text('Erro ao selecionar imagem: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _searchCep() async {
    final cep = _cepController.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (cep.length != 8) {
      _showErrorMessage('CEP inválido');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final dio = Dio();
      final response = await dio.get('https://viacep.com.br/ws/$cep/json/');

      if (response.data['erro'] == true) {
        throw Exception('CEP não encontrado');
      }

      setState(() {
        _streetController.text = response.data['logradouro'] ?? '';
        _neighborhoodController.text = response.data['bairro'] ?? '';
        _cityController.text = response.data['localidade'] ?? '';
        _stateController.text = response.data['uf'] ?? '';
      });
    } catch (e) {
      _showErrorMessage(e is Exception ? e.toString() : 'Erro ao buscar CEP');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await widget.authService.updateProfile(
        displayName: _nameController.text,
      );

      await _firestore
          .collection('users')
          .doc(widget.authService.currentUser!.uid)
          .set({
        'cpf': _cpfController.text,
        'phone': _phoneController.text,
        'cep': _cepController.text,
        'street': _streetController.text,
        'number': _numberController.text,
        'complement': _complementController.text,
        'neighborhood': _neighborhoodController.text,
        'city': _cityController.text,
        'state': _stateController.text,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil atualizado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showErrorMessage('Erro ao salvar perfil');
    } finally {
      setState(() => _isLoading = false);
    }
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
                    ),
                    _buildTextField(
                      controller: _cpfController,
                      label: 'CPF',
                      formatter: _cpfFormatter,
                      keyboardType: TextInputType.number,
                    ),
                    _buildTextField(
                      controller: _phoneController,
                      label: 'Telefone',
                      formatter: _phoneFormatter,
                      keyboardType: TextInputType.phone,
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
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _cepController,
                            label: 'CEP',
                            formatter: _cepFormatter,
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              if (value.length == 9) {
                                _searchCep();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    _buildTextField(
                      controller: _streetController,
                      label: 'Rua',
                      readOnly: true,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _numberController,
                            label: 'Número',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _complementController,
                            label: 'Complemento',
                            validator: null,
                          ),
                        ),
                      ],
                    ),
                    _buildTextField(
                      controller: _neighborhoodController,
                      label: 'Bairro',
                      readOnly: true,
                    ),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: _buildTextField(
                            controller: _cityController,
                            label: 'Cidade',
                            readOnly: true,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _stateController,
                            label: 'Estado',
                            readOnly: true,
                          ),
                        ),
                      ],
                    ),
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
            content: Text(e.toString()),
            backgroundColor: Colors.red,
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
