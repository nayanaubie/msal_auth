import 'package:flutter/services.dart';

import '../models/models.dart';

extension PlatformExceptionUtils on PlatformException {
  /// Converts the [PlatformException] to [MsalException]
  MsalException convertToMsalException() {
    final message = this.message ?? '';
    final map = details is Map ? (details as Map).cast<String, dynamic>() : {};
    final correlationId = map['correlationId'] as String?;

    return switch (code) {
      'USER_CANCEL' =>
        MsalUserCancelException(message: message, correlationId: correlationId),
      'DECLINED_SCOPE' => MsalDeclinedScopeException(
          grantedScopes: (map['grantedScopes'] as List<dynamic>).cast<String>(),
          declinedScopes:
              (map['declinedScopes'] as List<dynamic>).cast<String>(),
          message: message,
          correlationId: correlationId,
        ),
      'PROTECTION_POLICY_REQUIRED' => MsalProtectionPolicyRequiredException(
          accountUpn: map['accountUpn'],
          accountUserId: map['accountUserId'],
          tenantId: map['tenantId'],
          authorityUrl: map['authorityUrl'],
          message: message,
          correlationId: correlationId,
        ),
      'UI_REQUIRED' => MsalUiRequiredException(
          oauthSubErrorCode: map['oauthSubErrorCode'],
          oauthError: map['oauthError'],
          oauthErrorDescription: map['oauthErrorDescription'],
          message: message,
          correlationId: correlationId,
        ),
      'INVALID_ARGUMENT' => MsalArgumentException(
          argumentName: map['argumentName'],
          operationName: map['operationName'],
          message: message,
          correlationId: correlationId,
        ),
      'CLIENT_ERROR' => MsalClientException(
          errorCode: map['errorCode'],
          message: message,
          correlationId: correlationId,
        ),
      'SERVICE_ERROR' => MsalServiceException(
          errorCode: map['errorCode'],
          httpStatusCode: map['httpStatusCode'],
          message: message,
          correlationId: correlationId,
        ),
      'UNSUPPORTED_BROKER' => MsalUnsupportedBrokerException(
          activeBrokerPackageName: map['activeBrokerPackageName'],
          message: message,
          correlationId: correlationId,
        ),
      'INTERNAL_ERROR' => MsalInternalException(
          message: message,
          correlationId: correlationId,
          errorCode: map['internalErrorCode'],
        ),
      'WORKPLACE_JOIN_REQUIRED' => MsalWorkplaceJoinRequiredException(
          message: message,
          correlationId: correlationId,
        ),
      'SERVER_ERROR' =>
        MsalServerException(message: message, correlationId: correlationId),
      'INSUFFICIENT_DEVICE_STRENGTH' => MsalInsufficientDeviceStrengthException(
          message: message,
          correlationId: correlationId,
        ),
      'NO_CURRENT_ACCOUNT' => MsalNoCurrentAccountException(message: message),
      'PCA_INIT' => MsalPcaInitException(message: message),
      _ => MsalException(message: message, correlationId: correlationId),
    };
  }
}
