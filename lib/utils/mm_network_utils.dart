import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:intl/intl.dart';
import 'package:mm_utils/utils/int_extensions.dart';

import '../mm_utils.dart';
import '../model/master_response_class.dart';
import 'mm_common.dart';
import 'mm_constant.dart';
import 'mm_encryption_file.dart';

var errorSomethingWentWrong = 'Something Went Wrong';

Map<String, String> buildHeaderTokens() {
  Map<String, String> header = {
    HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
    HttpHeaders.cacheControlHeader: 'no-cache',
    HttpHeaders.acceptHeader: 'application/json; charset=utf-8',
    'Access-Control-Allow-Headers': '*',
    'Access-Control-Allow-Origin': '*',
  };

  if (MmUtils.instance!.getToken().isNotEmpty) {
    header.putIfAbsent(HttpHeaders.authorizationHeader,
        () => 'Bearer ${MmUtils.instance!.getToken()}');
  }

  return header;
}

Uri buildBaseUrl(String endPoint) {
  Uri url = Uri.parse(endPoint);
  if (!endPoint.startsWith('http')) {
    url = Uri.parse(
        '${MmUtils.instance!.getBaseUrl()}${MmUtils.instance!.getApiPath()}$endPoint');
  }
  return url;
}

getEncryptRequest(Map? request) {
  if (MmUtils.instance!.isEncryptData()) {
    String encryptRequest = jsonEncode(request);
    return Encryption.instance.encryptData(encryptRequest);
  }
  return request;
}

getDecryptDataResponse(dynamic response, {bool isJsonDecode = false}) {
  if (MmUtils.instance!.isEncryptData()) {
    try {
      String realResponse = Encryption.instance.decryptData(response);
      if (isJsonDecode) {
        return jsonDecode(realResponse);
      }
      return realResponse;
    } catch (e) {
      printLogs("Error from decryptData $e");
    }
    return "";
  } else {
    return response;
  }
}

Future<Response> buildHttpResponse(String endPoint,
    {HttpMethod method = HttpMethod.get, Map? request}) async {
  if (await isNetworkAvailable()) {
    DateTime startApiCall = DateTime.now();
    var headers = buildHeaderTokens();
    Uri url = buildBaseUrl(endPoint);

    dynamic requestData;

    if (MmUtils.instance!.isEncryptData()) {
      requestData = {"requestData": getEncryptRequest(request)};
    } else {
      requestData = request;
    }

    Response response;

    if (method == HttpMethod.post) {
      response =
          await http.post(url, body: jsonEncode(requestData), headers: headers);
    } else if (method == HttpMethod.delete) {
      response = await delete(url, headers: headers);
    } else if (method == HttpMethod.put) {
      response =
          await put(url, body: jsonEncode(requestData), headers: headers);
    } else {
      response = await get(url, headers: headers);
    }

    if (MmUtils.instance!.isPrintLog()) {
      DateTime endApiCall = DateTime.now();

      apiURLResponseLog(
          url: url.toString(),
          endPoint: endPoint,
          headers: jsonEncode(headers),
          hasRequest: method == HttpMethod.post || method == HttpMethod.put,
          request: jsonEncode(request),
          encryptRequest: getEncryptRequest(request),
          statusCode: response.statusCode.validate(),
          encryptResponse: (MmUtils.instance!.isEncryptData())
              ? MasterResponseClass.fromJson(jsonDecode(response.body))
                  .requestData!
              : "",
          responseBody: getDecryptDataResponse(
              MasterResponseClass.fromJson(jsonDecode(response.body))
                  .requestData!),
          methodType: method.name,
          startTime: startApiCall,
          endTime: endApiCall);
    }

    return response;
  } else {
    throw errorInternetNotAvailable;
  }
}

Future handleResponse(Response response) async {
  // if (!await isNetworkAvailable()) {
  //   throw errorInternetNotAvailable;
  // }

  if (response.statusCode.isSuccessful()) {
    var v = MasterResponseClass.fromJson(jsonDecode(response.body));
    return getDecryptDataResponse(v.requestData!, isJsonDecode: true);
  } else {
    var string = await (isJsonValid(response.body));
    if (string!.isNotEmpty) {
    } else {
      throw 'Please try again later.';
    }
  }
}

//region Common
enum HttpMethod { get, post, delete, put }

class TokenException implements Exception {
  final String message;

  const TokenException([this.message = ""]);

  @override
  String toString() => "FormatException: $message";
}
//endregion

Future<String?> isJsonValid(json) async {
  try {
    var f = jsonDecode(json) as Map<String, dynamic>;
    return f['message'];
  } catch (e) {
    printLogs(e.toString());
    return "";
  }
}

JsonDecoder decoder = JsonDecoder();
JsonEncoder encoder = JsonEncoder.withIndent('  ');

void prettyPrintJson(String input) {
  var object = decoder.convert(input);
  var prettyString = encoder.convert(object);
  prettyString.split('\n').forEach((element) => _printLogsForRequest(element));
}

void apiURLResponseLog({
  String url = "",
  String endPoint = "",
  String headers = "",
  dynamic request = "",
  dynamic encryptRequest = "",
  String encryptResponse = "",
  int statusCode = 0,
  dynamic responseBody = "",
  String methodType = "",
  bool hasRequest = false,
  DateTime? startTime,
  DateTime? endTime,
}) {
  String currentDate =
      "${MmUtils.instance!.getAppName()} : ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}";

  _printLogsForRequest(
      "\u001B[39m \u001b[96m┌─────────────────────────── \u001b[31m Start log report from $currentDate \u001b[96m ───────────────────────────┐\u001B[39m");

  if (startTime != null && endTime != null) {
    Duration difference = endTime.difference(startTime);
    int minutes = difference.inMinutes % 60; // Remaining minutes
    int seconds = difference.inSeconds % 60; // Remaining seconds
    int milliseconds =
        difference.inMilliseconds % 1000; // Remaining milliseconds
    _printLogsForRequest(
        "\u001b[31m Api execution time (mm:ss:ms): \u001B[39m $minutes:$seconds:$milliseconds");
  }
  _printLogsForRequest("\u001b[31m Url: \u001B[39m $url");
  _printLogsForRequest(
      "\u001b[31m Header: \u001B[39m \u001b[96m$headers\u001B[39m");
  if (request != null && request.isNotEmpty) {
    _printLogsForRequest(
        "\u001b[31m Request: \u001B[39m \u001b[96m$request\u001B[39m");
  }

  if (encryptRequest != null && encryptRequest.isNotEmpty) {
    _printLogsForRequest(
        "\u001b[31m Encrypt Request: \u001B[39m \u001b[96m$encryptRequest\u001B[39m");
  }

  if (encryptResponse.isNotEmpty) {
    _printLogsForRequest(
        "\u001b[31m Encrypt Response: \u001B[39m \u001b[96m$encryptResponse\u001B[39m");
  }
  _printLogsForRequest(statusCode.isSuccessful() ? "\u001b[32m" : "\u001b[31m");
  _printLogsForRequest(
      'Response ($methodType) $statusCode ${statusCode.isSuccessful() ? "\u001b[32m" : "\u001b[31m"} ');
  //if(responseBody!=null) {
  _printLogsForRequest(responseBody);
  //}
  _printLogsForRequest("\u001B[0m");
  String engLog =
      "${MmUtils.instance!.getAppName()} : ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}";

  _printLogsForRequest(
      "\u001B[39m \u001b[96m└─────────────────────────── \u001b[31m Log report end from $engLog \u001b[96m ───────────────────────────┘\u001B[39m");
}

Future<MultipartRequest> getMultiPartRequest(String endPoint,
    {String? baseUrl}) async {
  String url = baseUrl ?? buildBaseUrl(endPoint).toString();
  printLogs(url);
  return MultipartRequest('POST', Uri.parse(url));
}

Future<void> sendMultiPartRequest(MultipartRequest multiPartRequest,
    {Function(dynamic)? onSuccess, Function(dynamic)? onError}) async {
  http.Response response =
      await http.Response.fromStream(await multiPartRequest.send());
  printLogs("Result: ${response.body}");

  if (response.statusCode.isSuccessful()) {
    onSuccess?.call(response.body);
  } else {
    onError?.call(errorSomethingWentWrong);
  }
}

/// Print logs to console
printLogs(Object? value) {
  String currentDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
  if (MmUtils.instance!.isPrintLog()) {
    if (kDebugMode) {
      print("${MmUtils.instance!.getAppName()} $currentDate: $value");
    }
  }
}

/// Print logs to console
_printLogsForRequest(Object? value) {
  if (MmUtils.instance!.isPrintLog()) {
    if (kDebugMode) {
      print("$value");
    }
  }
}
