import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../models/user_model.dart';

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final UserModel? user;
  final String? error;

  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.user,
    this.error,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    UserModel? user,
    String? error,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _apiClient;

  AuthNotifier(this._apiClient) : super(const AuthState()) {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final hasToken = await _apiClient.hasValidToken();
    if (!hasToken) {
      state = state.copyWith(isAuthenticated: false, isLoading: false);
      return;
    }

    state = state.copyWith(isLoading: true);
    try {
      final response = await _apiClient.getCurrentUser();
      if (response.statusCode == 200) {
        final user = UserModel.fromJson(response.data);
        state = state.copyWith(
          isAuthenticated: true,
          isLoading: false,
          user: user,
        );
        return;
      }
    } catch (e) {
      await _apiClient.clearTokens();
    }

    state = state.copyWith(isAuthenticated: false, isLoading: false);
  }

  Future<bool> login(String email, String password, {bool isAutoLogin = false}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _apiClient.login(email, password);

      if (response.statusCode == 200) {
        await _apiClient.saveTokens(
          response.data['access_token'],
          response.data['refresh_token'],
        );

        // Get user info
        final userResponse = await _apiClient.getCurrentUser();
        if (userResponse.statusCode == 200) {
          final user = UserModel.fromJson(userResponse.data);
          state = state.copyWith(
            isAuthenticated: true,
            isLoading: false,
            user: user,
          );
          return true;
        }
      }

      state = state.copyWith(
        isLoading: false,
        error: isAutoLogin ? 'Account created but auto-login failed. Please sign in.' : 'Invalid email or password.',
      );
      return false;
    } catch (e) {
      String errorMsg = 'Invalid email or password.';
      if (e is DioException && e.response?.statusCode == 401) {
        errorMsg = 'Invalid email or password.';
      } else if (e is DioException && e.response?.statusCode == 404) {
        errorMsg = 'Invalid email or password.';
      }
      state = state.copyWith(
        isLoading: false,
        error: isAutoLogin ? 'Account created! Please sign in.' : errorMsg,
      );
      return false;
    }
  }

  Future<bool> register(String email, String password, String name) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _apiClient.register(email, password, name);

      if (response.statusCode == 201) {
        // Auto login after registration
        return await login(email, password, isAutoLogin: true);
      }

      state = state.copyWith(
        isLoading: false,
        error: response.data['detail'] ?? 'Registration failed. Please try again.',
      );
      return false;
    } catch (e) {
      String errorMsg = 'Registration failed. Please try again.';
      if (e is DioException) {
        final statusCode = e.response?.statusCode;
        final detail = e.response?.data?['detail'];
        if (statusCode == 400 && detail != null) {
          if (detail.toString().toLowerCase().contains('email')) {
            errorMsg = 'This email is already registered. Please sign in instead.';
          } else {
            errorMsg = detail.toString();
          }
        } else if (statusCode == 409) {
          errorMsg = 'This email is already registered. Please sign in instead.';
        }
      }
      state = state.copyWith(
        isLoading: false,
        error: errorMsg,
      );
      return false;
    }
  }

  Future<bool> requestPasswordReset(String email) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      await _apiClient.requestPasswordReset(email);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false);
      return true; // Always return true to prevent email enumeration
    }
  }

  Future<void> logout() async {
    await _apiClient.clearTokens();
    state = const AuthState();
  }

  Future<bool> updateProfile({String? name}) async {
    try {
      final response = await _apiClient.updateProfile({
        if (name != null) 'name': name,
      });

      if (response.statusCode == 200) {
        final user = UserModel.fromJson(response.data);
        state = state.copyWith(user: user);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> uploadAvatar(List<int> bytes, String filename, String mimeType) async {
    try {
      final response = await _apiClient.uploadAvatar(bytes, filename, mimeType);

      if (response.statusCode == 200) {
        final user = UserModel.fromJson(response.data);
        state = state.copyWith(user: user);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> removeAvatar() async {
    try {
      final response = await _apiClient.removeAvatar();

      if (response.statusCode == 200) {
        final user = UserModel.fromJson(response.data);
        state = state.copyWith(user: user);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<String?> changePassword(String currentPassword, String newPassword) async {
    try {
      final response = await _apiClient.changePassword(currentPassword, newPassword);

      if (response.statusCode == 200) {
        return null; // Success
      }
      return 'Failed to change password';
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 400) {
        return e.response?.data['detail'] ?? 'Current password is incorrect';
      }
      return 'Failed to change password';
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthNotifier(apiClient);
});
