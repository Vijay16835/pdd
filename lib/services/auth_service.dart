import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:lexguard_ai/core/constants/api_constants.dart';
import 'package:lexguard_ai/services/api_service.dart';

class AuthService {
  final ApiService _api = ApiService();

  Future<Map<String, dynamic>> login(String email, String password) async {
    debugPrint('[AuthService] login() called with email: $email');
    try {
      debugPrint('[AuthService] Sending POST to: ${ApiConstants.login}');
      final response = await _api.post(
        ApiConstants.login,
        data: {'email': email, 'password': password},
      );
      debugPrint('[AuthService] Response received: ${response.data}');
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      debugPrint('[AuthService] DioException in login: ${e.type}');
      if (e.response != null) {
        debugPrint('[AuthService] Backend response status: ${e.response?.statusCode}');
        debugPrint('[AuthService] Backend response data: ${e.response?.data}');
      }
      debugPrint('[AuthService] Exception in login: $e');
      return {'success': false, 'message': e.message ?? e.toString()};
    } catch (e) {
      debugPrint('[AuthService] Exception in login: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> healthCheck() async {
    try {
      final response = await _api.get(ApiConstants.health);
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> signUp(String name, String email, String password) async {
    try {
      final response = await _api.post(
        ApiConstants.signup,
        data: {
          'full_name': name,
          'email': email,
          'password': password,
        },
      );
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> sendOtp(String email) async {
    try {
      final response = await _api.post(
        ApiConstants.sendOtp,
        data: {'email': email},
      );
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> verifyOtp(String email, String otp) async {
    try {
      final response = await _api.post(
        ApiConstants.verifyOtp,
        data: {'email': email, 'otp': otp},
      );
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> sendResetOtp(String email) async {
    try {
      final response = await _api.post(
        ApiConstants.sendResetOtp,
        data: {'email': email},
      );
      return {'success': true, 'message': response.data['message']};
    } catch (e) {
      return {'success': false, 'message': _extractErrorMessage(e)};
    }
  }

  String _extractErrorMessage(dynamic e) {
    if (e is DioException) {
      if (e.response != null && e.response!.data != null) {
        final data = e.response!.data;
        if (data is Map) {
          if (data['detail'] != null) return data['detail'].toString();
          if (data['message'] != null) return data['message'].toString();
        }
      }
      return e.message ?? e.toString();
    }
    return e.toString();
  }

  Future<Map<String, dynamic>> verifyResetOtp(String email, String otp) async {
    try {
      final response = await _api.post(
        ApiConstants.verifyResetOtp,
        data: {'email': email, 'otp': otp},
      );
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> resetPassword(String email, String otp, String newPassword) async {
    try {
      final response = await _api.post(
        ApiConstants.resetPassword,
        data: {'email': email, 'otp': otp, 'new_password': newPassword},
      );
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> googleAuth(
    String email,
    String name,
    String? photoUrl, {
    required String firebaseUid,
    String? idToken,
  }) async {
    try {
      final response = await _api.post(
        ApiConstants.googleAuth,
        data: {
          'firebase_uid': firebaseUid,   // Required — primary key for Google users
          'id_token': idToken,
          'email': email,
          'full_name': name,
          'profile_image': photoUrl,
        },
      );
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    try {
      // Changed to use relative path matching user.py router
      final response = await _api.put('/user/profile', data: data);
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> changePassword(String currentPassword, String newPassword) async {
    try {
      final response = await _api.post(
        ApiConstants.changePassword,
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
      );
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getMe() async {
    try {
      final response = await _api.get(ApiConstants.me);
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
  Future<Map<String, dynamic>> logout(String? refreshToken) async {
    try {
      final response = await _api.post(
        ApiConstants.logout,
        data: {'refresh_token': refreshToken},
      );
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    try {
      final response = await _api.post(
        ApiConstants.refreshToken,
        data: {'refresh_token': refreshToken},
      );
      return {'success': true, 'data': response.data};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
