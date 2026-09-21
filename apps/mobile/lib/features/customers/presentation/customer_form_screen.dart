import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/customer.dart';
import '../../../repositories/customer_repository.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../business_selection/providers/business_provider.dart';
import '../providers/customers_provider.dart';

class CustomerFormScreen extends ConsumerStatefulWidget {
  const CustomerFormScreen({super.key, this.customerId});

  final String? customerId;

  @override
  ConsumerState<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends ConsumerState<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isLoading = false;
  Customer? _existingCustomer;

  bool get isEditing => widget.customerId != null && widget.customerId != 'new';

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _loadCustomer();
    }
  }

  Future<void> _loadCustomer() async {
    setState(() => _isLoading = true);
    final customer = await ref.read(customerProvider(widget.customerId!).future);
    if (customer != null && mounted) {
      _existingCustomer = customer;
      _nameController.text = customer.name;
      _mobileController.text = customer.mobile ?? '';
      _emailController.text = customer.email ?? '';
      _addressController.text = customer.address ?? '';
      _notesController.text = customer.notes ?? '';
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final business = ref.read(activeBusinessProvider);
    if (business == null) return;

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(customerRepositoryProvider);
      final customer = Customer(
        id: _existingCustomer?.id ?? '',
        businessId: business.id,
        name: _nameController.text.trim(),
        mobile: _mobileController.text.trim().isEmpty ? null : _mobileController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      if (isEditing) {
        await repo.updateCustomer(customer);
      } else {
        await repo.createCustomer(customer);
      }

      ref.invalidate(customersProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Customer' : 'Add Customer'),
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name *',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile',
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    prefixIcon: Icon(Icons.location_on),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    prefixIcon: Icon(Icons.notes),
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  child: _isLoading
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text('Saving…'),
                          ],
                        )
                      : Text(isEditing ? 'Update Customer' : 'Save Customer'),
                ),
              ],
            ),
          ),
          LoadingOverlay(
            isVisible: _isLoading,
            message: isEditing ? 'Updating customer…' : 'Saving customer…',
          ),
        ],
      ),
    );
  }
}
