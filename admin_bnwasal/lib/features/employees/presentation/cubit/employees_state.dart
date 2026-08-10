import 'package:equatable/equatable.dart';

class EmployeesState extends Equatable {
  final bool isLoading;
  final String? error;
  final List<dynamic> employees;
  final int total;
  final int page;
  final String search;
  final bool isSubmitting;
  final String? submitError;
  final String? submitSuccess;

  const EmployeesState({
    this.isLoading = false,
    this.error,
    this.employees = const [],
    this.total = 0,
    this.page = 1,
    this.search = '',
    this.isSubmitting = false,
    this.submitError,
    this.submitSuccess,
  });

  EmployeesState copyWith({
    bool? isLoading, String? error,
    List<dynamic>? employees, int? total, int? page, String? search,
    bool? isSubmitting, String? submitError, String? submitSuccess,
  }) {
    return EmployeesState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      employees: employees ?? this.employees,
      total: total ?? this.total,
      page: page ?? this.page,
      search: search ?? this.search,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitError: submitError,
      submitSuccess: submitSuccess,
    );
  }

  @override
  List<Object?> get props => [isLoading, error, employees, total, page, search, isSubmitting, submitError, submitSuccess];
}
