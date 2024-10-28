import 'dart:convert';

import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:http/http.dart' as http;

class PushNotificationService {
  // Firebase Cloud Messaging endpoint for sending notifications.
  static const String _fcmEndpoint =
      'https://fcm.googleapis.com/v1/projects/bingo-bb0fb/messages:send';

  // Get the access token using the service account credentials.
  static Future<String?> getAccessToken() async {
    final serviceAccountJson = {
      "type": "service_account",
      "project_id": "bingo-bb0fb",
      "private_key_id": "53fbbb8b86482953502553272cf5bd49593d9060",
      "private_key":
          "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDFnakLlscMYhH2\nbLERmJ1fQpzO8dbBBmkeX0OOqHUXeBz1Nx5C34cR06kZl8reHlrKxkDAaXbVvRIt\nS7qAAHz2IKya0vaowz0Qg0E8H9aMe1IL/0Q4NiCUDi6VS0rWSIUQQhqhu8S/e/0v\nMWkNCWg2qV2yJ9zdkIN4uute1Z0X7Mbo461MK1hNbqPBsdvdIsto+Jb97muRSUe5\nmhgABhKRCkuMssQT+5/SOZuHtLr5w4TUaenPYcyZ8aV6UpvSsTcism6Vvi8mUt9z\nZxiumcXRUvLaD6ZFU6Wef1gn1B2KS+9ej2i+huN5cuklRbZdI4ildw5+YZcr+4VJ\nXsTC9UFXAgMBAAECggEAGLLW0PL8V8jeE92L1/YqHSDXNmo1fBSQCNLBP9BAKjnB\n7MgByTvkxs6cgO1e1poWoOdcanAEATzLS8v+OEdXVu/IguVBHOCh/jFZculLyG0V\nWRiDbz8cnUSUf+ZUKSoRL3IDoBk2wvP9NevIBHAbjVFnu3+N9Ec+l1VNW6H5K2cd\nT4b8iH+l6ALPHBE5xTwPHP+rpAWgJWpINrjFFGL8znhzFY9y20H6xhG81AscIn1D\nKG/48N+2DOzGhZ1IedSRmW1SkuA1GlVMBs3F0e0wznnbKlstCPY7zVnHPH/xWi8Z\nC7OlzqZPYNAu5D+cNQJXPNgCsYV/B8at6Bcc5IwY0QKBgQDiwlxs1JpROmS1VjZ3\ni5bUZXw//lmIOIdVOJfT43lUiSgBiHffH4szdaEMqOY73KEVHlKfNEb6HC6S+yUu\n3AQkR0Y+foIrk+j6BidHd/R73GIACxAYOJ4gTnVS4w1c4ADVNgVrmsh6j+9LYZ5N\n+s6eCKOMEvpDLOpvD93azdIuvwKBgQDfGTx1pVkCFZxKB1WUb15CzWRhIlvYOBWA\nFWcI2XIbpyU3q5PcZoVMwzesqX1TJveRMYobKtoZEuEf3HnmoZIOk1KPSJ9O2HDi\nxFwlG6xcUC5/mbMoiG89ARrpGav5AwpGS4WI7bvIm4SwKMaNtosqVVdKPWRffT9a\nNXih1ZoraQKBgF7k+4zHw/SuPSrt80k/71TfS4n0RT+OeIQfdNpFXacU5tsNYyzK\npJRaa5VCsWbnw7l0wRrC49kTJiJ4W20qwcj00t6gTpUyBtNq89Eiz/ttlM1z075v\nIy1d6BdR0WvGilKvksEfOzqfNYMUTQ1RIlpcPyUFZBnsmAb2Wt+QNp89AoGBALjf\njL5gupWDmvOtiDls4EuzME9dzYYrU4XENpGav3gy1iB/yhOF0Uh/LQ+jk/rn+5cR\n2kQRCpJklrF0Xn/Du+jgJDYgFAOeUE1aMpF9kSMePqn2kAQyqxt+YvJvF5dN8aG2\ny31go4/lb9sarw6YClKWTbNzlE2c2HbEgKZ6/zqhAoGAZMADr7zOwdhmsQVSiy13\nxYwyIH79SahzhuTle+lvlhh6at5oSM3hA0ZGzKPMtiBm0fJ9MiwTxMvDImHWEugw\nSBNxtZ2GZJZNGOiXOydkk8w9T29z/FVkwCv6TeKYhoe8/h/Zht1iLCa2AM2ZhJoC\nxXp8cvrT8b98mo26zMALn0k=\n-----END PRIVATE KEY-----\n",
      "client_email": "bingo-hariom@bingo-bb0fb.iam.gserviceaccount.com",
      "client_id": "116298231885953559358",
      "auth_uri": "https://accounts.google.com/o/oauth2/auth",
      "token_uri": "https://oauth2.googleapis.com/token",
      "auth_provider_x509_cert_url":
          "https://www.googleapis.com/oauth2/v1/certs",
      "client_x509_cert_url":
          "https://www.googleapis.com/robot/v1/metadata/x509/bingo-hariom%40bingo-bb0fb.iam.gserviceaccount.com",
      "universe_domain": "googleapis.com"
    };

    List<String> scopes = [
      "https://www.googleapis.com/auth/firebase.messaging",
    ];

    try {
      var client = await auth.clientViaServiceAccount(
          auth.ServiceAccountCredentials.fromJson(serviceAccountJson), scopes);

      var credentials = await auth.obtainAccessCredentialsViaServiceAccount(
          auth.ServiceAccountCredentials.fromJson(serviceAccountJson),
          scopes,
          client);
      client.close();
      return credentials.accessToken.data;
    } catch (e) {
      print("Error getting access token: $e");
      return null;
    }
  }

// Send a notification with a custom title and body to a specific device token.
  static Future<void> sendNotificationToUser(
      String deviceToken, String title, String body) async {
    final String? accessToken = await getAccessToken();
    if (accessToken == null) return;

    final message = {
      'message': {
        'token': deviceToken,
        'notification': {
          'title': title,
          'body': body,
        },
      }
    };

    try {
      final response = await http.post(
        Uri.parse(_fcmEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(message),
      );

      if (response.statusCode == 200) {
        print('Notification sent successfully!');
      } else {
        print('Failed to send notification: ${response.body}');
      }
    } catch (e) {
      print('Error sending notification: $e');
    }
  }
}
