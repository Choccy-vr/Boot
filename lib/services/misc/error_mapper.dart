import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

class ErrorMapper {
  static String mapError(Object error) {
    if (error is PostgrestException) {
      //Postgrestexception
      return mapPostgrestException(error);
    }
    if (error is AuthException) {
      //AuthException
      return mapAuthError(error);
    }
    if (error is TimeoutException) {
      //TimeoutException
      return 'The request timed out. Please check your internet connection and try again.';
    }
    if (error is SocketException) {
      //SocketException
      return _mapNetworkError(error);
    }
    //generic fallback
    return 'An unexpected error occurred: $error';
  }

  static String mapPostgrestException(PostgrestException error) {
    final code = error.code;
    final message = error.message.toLowerCase();

    switch (code) {
      case '23505':
        return _mapUniqueConstraintViolation(message);
      case '23502':
        // Not null violation
        return 'A required field is missing or invalid.';
      case '22001':
        // String data right truncation
        return 'A field value is too long. Please shorten it and try again.';
      case '23503':
        // Foreign key violation
        return 'A related record is missing. Please ensure all related data exists and try again.';
      default:
        return 'A database error occurred: $message (code: $code)';
    }
  }

  static String _mapUniqueConstraintViolation(String message) {
    if (message.contains('email')) {
      return 'The email address is already in use. Please use a different email.';
    }
    if (message.contains('username')) {
      return 'The username is already taken. Please choose a different username.';
    }
    if (message.contains('slack_user_id')) {
      return 'The Slack user ID is already associated with another account. Please use a different Slack user ID.';
    }
    if (message.contains('hc_user_id')) {
      return 'The HCA user ID is already associated with another account. Please use a different HCA user ID.';
    }
    if (message.contains('ISO_url')) {
      return 'The ISO URL is already associated with another project. Please use a different ISO URL.';
    }
    if (message.contains('projects_name_key')) {
      return 'There is already a project with this name. Please choose a different name for your project.';
    }
    return 'A unique constraint violation occurred. Please ensure all values are unique and try again.';
  }

  static String _mapNetworkError(Object error) {
    return 'Network error. Check your internet connection and try again.';
  }

  static String mapAuthError(AuthException error) {
    switch (error.message) {
      case 'User already exists':
        return 'An account with this email already exists. Please log in or use a different email.';
      default:
        return 'Authentication error: ${error.message}';
    }
  }
}
