import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class CarsScreen extends StatefulWidget {
  final FirebaseFirestore? firestore;
  final FirebaseAuth? auth;
  const CarsScreen({super.key, this.firestore, this.auth});

  @override
  State<CarsScreen> createState() => _CarsScreenState();
}

class _CarsScreenState extends State<CarsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _modelController = TextEditingController();
  final _plateController = TextEditingController();
  final _colorController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  late final FirebaseFirestore _firestore;
  late final FirebaseAuth _auth;

  File? _imageFile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _firestore = widget.firestore ?? FirebaseFirestore.instance;
    _auth = widget.auth ?? FirebaseAuth.instance;
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
        debugPrint('Imagem selecionada: ${pickedFile.path}');
      }
    } catch (e) {
      debugPrint('Erro ao selecionar imagem: $e');
      _showErrorMessage('Erro ao selecionar imagem: $e');
    }
  }

  Future<String?> _uploadImage() async {
    if (_imageFile == null) return null;

    try {
      final user = _auth.currentUser;
      if (user == null) throw ('Usuário não autenticado');

      final String extension =
          _imageFile!.path.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
      final fileName =
          'car_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('car_photos')
          .child(user.uid)
          .child(fileName);

      final metadata = SettableMetadata(
        contentType: extension == 'png' ? 'image/png' : 'image/jpeg',
        customMetadata: {
          'userId': user.uid,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      await storageRef.putFile(_imageFile!, metadata);
      return await storageRef.getDownloadURL();
    } catch (e) {
      debugPrint('Erro ao fazer upload da imagem: $e');
      _showErrorMessage('Erro ao fazer upload da imagem: $e');
      return null;
    }
  }

  Future<void> _saveCar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      debugPrint('=== Iniciando salvamento do carro ===');
      
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('ERRO: Usuário não autenticado');
        throw ('Usuário não autenticado');
      }

      debugPrint('Usuário autenticado: ${user.uid}');
      debugPrint('Nome: ${_nameController.text}');
      debugPrint('Modelo: ${_modelController.text}');
      debugPrint('Placa: ${_plateController.text}');
      debugPrint('Cor: ${_colorController.text}');

      String? photoUrl;
      if (_imageFile != null) {
        debugPrint('Upload de imagem iniciado...');
        photoUrl = await _uploadImage();
        if (photoUrl != null) {
          debugPrint('Upload concluído: $photoUrl');
        } else {
          debugPrint('Upload falhou - continuando sem foto');
        }
      }

      final carData = {
        'name': _nameController.text.trim(),
        'model': _modelController.text.trim(),
        'plate': _plateController.text.trim().toUpperCase(),
        'color': _colorController.text.trim(),
        if (photoUrl != null) 'photoUrl': photoUrl,
        'createdAt': FieldValue.serverTimestamp(),
      };

      debugPrint('Salvando no Firestore: $carData');

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('cars')
          .add(carData);

      debugPrint('Carro salvo com sucesso!');
      
      if (!mounted) return;
      
      _showSuccessMessage('Carro adicionado com sucesso!');
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e, stackTrace) {
      debugPrint('=== ERRO ao salvar carro ===');
      debugPrint('Erro: $e');
      debugPrint('StackTrace: $stackTrace');
      
      if (!mounted) return;
      
      _showErrorMessage('Erro ao salvar carro: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
    TextInputType? keyboardType,
    TextInputFormatter? formatter,
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
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Campo obrigatório';
          }
          return null;
        },
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _modelController.dispose();
    _plateController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Adicionar Carro',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      image: _imageFile != null
                          ? DecorationImage(
                              image: FileImage(_imageFile!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _imageFile == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo,
                                size: 40,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Adicionar foto',
                                style: GoogleFonts.poppins(
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildTextField(
                controller: _nameController,
                label: 'Marca',
                hint: 'Ex: Volkswagen, Fiat, Chevrolet',
              ),
              _buildTextField(
                controller: _modelController,
                label: 'Modelo',
                hint: 'Ex: Gol 1.0',
              ),
              _buildTextField(
                controller: _plateController,
                label: 'Placa',
                hint: 'Ex: ABC1234',
              ),
              _buildTextField(
                controller: _colorController,
                label: 'Cor',
                hint: 'Ex: Preto',
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveCar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Salvar Carro',
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
}
