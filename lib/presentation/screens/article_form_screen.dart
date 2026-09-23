import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/models/article_model.dart';
import '../../logic/article/article_cubit.dart';
import '../../logic/article/article_state.dart';
import '../../core/constants/app_constants.dart';

class ArticleFormScreen extends StatefulWidget {
  final ArticleModel? article;

  const ArticleFormScreen({super.key, this.article});

  @override
  State<ArticleFormScreen> createState() => _ArticleFormScreenState();
}

class _ArticleFormScreenState extends State<ArticleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late TextEditingController _imageUrlController;
  File? _image;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.article?.title ?? '');
    _contentController = TextEditingController(text: widget.article?.content ?? '');
    _imageUrlController = TextEditingController(text: widget.article?.imageUrl ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (!AppConstants.allowImageUpload) return;
    
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final cubit = context.read<ArticleCubit>();
      final imageUrl = _imageUrlController.text.trim().isEmpty ? null : _imageUrlController.text.trim();
      
      if (widget.article == null) {
        cubit.createArticle(
          title: _titleController.text,
          content: _contentController.text,
          image: _image,
          imageUrl: imageUrl,
        );
      } else {
        cubit.updateArticle(
          id: widget.article!.id,
          title: _titleController.text,
          content: _contentController.text,
          image: _image,
          imageUrl: imageUrl,
          existingImageUrl: widget.article!.imageUrl,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ArticleCubit, ArticleState>(
      listener: (context, state) {
        if (state is ArticleOperationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message)));
          Navigator.pop(context);
        } else if (state is ArticleError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white, // Ensure form screen background is white
        appBar: AppBar(
          title: Text(widget.article == null ? 'New Article' : 'Edit Article'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _contentController,
                  decoration: const InputDecoration(labelText: 'Content'),
                  maxLines: 5,
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _imageUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Image URL',
                    hintText: 'Paste an image URL here',
                  ),
                  onChanged: (v) => setState(() {}),
                ),
                if (AppConstants.allowImageUpload) ...[
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _image != null
                          ? Image.file(_image!, fit: BoxFit.cover)
                          : widget.article?.imageUrl != null
                              ? Image.network(widget.article!.imageUrl!, fit: BoxFit.cover)
                              : const Icon(Icons.add_a_photo, size: 50),
                    ),
                  ),
                ] else if (_imageUrlController.text.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      _imageUrlController.text,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 200,
                        width: double.infinity,
                        color: Colors.grey[300],
                        child: const Icon(Icons.broken_image, size: 50),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text('Save Article', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
