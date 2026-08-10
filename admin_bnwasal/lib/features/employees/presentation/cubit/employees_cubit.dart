import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/employees_api.dart';
import 'employees_state.dart';

class EmployeesCubit extends Cubit<EmployeesState> {
  final EmployeesApi _api;
  EmployeesCubit(this._api) : super(const EmployeesState());

  Future<void> loadEmployees({bool refresh = false}) async {
    if (refresh) {
      emit(state.copyWith(isLoading: true, error: null, page: 1));
    } else {
      emit(state.copyWith(isLoading: true, error: null));
    }
    try {
      final response = await _api.getEmployees(page: state.page, limit: 20, search: state.search);
      final data = response['data'] as Map<String, dynamic>;
      final employees = data['employees'] as List<dynamic>;
      emit(state.copyWith(
        isLoading: false,
        employees: refresh ? employees : [...state.employees, ...employees],
        total: data['total'] as int,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  void search(String query) {
    emit(state.copyWith(search: query, page: 1));
    loadEmployees(refresh: true);
  }

  void loadMore() {
    if (state.employees.length >= state.total) return;
    emit(state.copyWith(page: state.page + 1));
    loadEmployees();
  }

  Future<bool> createEmployee(Map<String, dynamic> data) async {
    emit(state.copyWith(isSubmitting: true, submitError: null, submitSuccess: null));
    try {
      await _api.createEmployee(data);
      emit(state.copyWith(isSubmitting: false, submitSuccess: 'تم إضافة الموظف بنجاح'));
      loadEmployees(refresh: true);
      return true;
    } catch (e) {
      emit(state.copyWith(isSubmitting: false, submitError: e.toString()));
      return false;
    }
  }

  Future<bool> updateEmployee(int id, Map<String, dynamic> data) async {
    emit(state.copyWith(isSubmitting: true, submitError: null, submitSuccess: null));
    try {
      await _api.updateEmployee(id, data);
      emit(state.copyWith(isSubmitting: false, submitSuccess: 'تم تحديث بيانات الموظف'));
      loadEmployees(refresh: true);
      return true;
    } catch (e) {
      emit(state.copyWith(isSubmitting: false, submitError: e.toString()));
      return false;
    }
  }

  Future<bool> deleteEmployee(int id) async {
    emit(state.copyWith(isSubmitting: true, submitError: null, submitSuccess: null));
    try {
      await _api.deleteEmployee(id);
      emit(state.copyWith(isSubmitting: false, submitSuccess: 'تم حذف الموظف'));
      loadEmployees(refresh: true);
      return true;
    } catch (e) {
      emit(state.copyWith(isSubmitting: false, submitError: e.toString()));
      return false;
    }
  }

  void clearSubmit() {
    emit(state.copyWith(submitError: null, submitSuccess: null));
  }
}
