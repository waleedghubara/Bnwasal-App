import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/get_addresses_usecase.dart';
import '../../domain/usecases/add_address_usecase.dart';
import '../../domain/usecases/update_address_usecase.dart';
import '../../domain/usecases/delete_address_usecase.dart';
import '../../../shipment/data/datasources/egypt_locations.dart';
import 'address_state.dart';

class AddressCubit extends Cubit<AddressState> {
  final GetAddressesUseCase _getAddresses;
  final AddAddressUseCase _addAddress;
  final UpdateAddressUseCase _updateAddress;
  final DeleteAddressUseCase _deleteAddress;

  AddressCubit({
    required GetAddressesUseCase getAddresses,
    required AddAddressUseCase addAddress,
    required UpdateAddressUseCase updateAddress,
    required DeleteAddressUseCase deleteAddress,
  })  : _getAddresses = getAddresses,
        _addAddress = addAddress,
        _updateAddress = updateAddress,
        _deleteAddress = deleteAddress,
        super(const AddressInitial());

  Future<void> loadAddresses() async {
    emit(const AddressLoading());
    final result = await _getAddresses();
    result.fold(
      (failure) => emit(AddressError(failure.message)),
      (addresses) => emit(AddressLoaded(addresses)),
    );
  }

  Future<void> saveAddress({
    required String? id,
    required String title,
    required String address,
    required String governorate,
    required String city,
    double? latitude,
    double? longitude,
    String? phone,
  }) async {
    emit(const AddressLoading());
    final savedAddr = SavedAddress(
      id: id ?? '',
      title: title,
      address: address,
      governorate: governorate,
      city: city,
      latitude: latitude,
      longitude: longitude,
      phone: phone,
    );

    if (id != null && id.isNotEmpty) {
      final result = await _updateAddress(savedAddr);
      result.fold(
        (failure) => emit(AddressError(failure.message)),
        (addr) => emit(const AddressActionSuccess('تم تحديث العنوان بنجاح')),
      );
    } else {
      final result = await _addAddress(savedAddr);
      result.fold(
        (failure) => emit(AddressError(failure.message)),
        (addr) => emit(const AddressActionSuccess('تم حفظ العنوان بنجاح')),
      );
    }
  }

  Future<void> removeAddress(String id) async {
    emit(const AddressLoading());
    final result = await _deleteAddress(id);
    result.fold(
      (failure) => emit(AddressError(failure.message)),
      (_) => emit(const AddressActionSuccess('تم حذف العنوان بنجاح')),
    );
  }

  @override
  void emit(AddressState state) {
    if (isClosed) return;
    super.emit(state);
  }
}
