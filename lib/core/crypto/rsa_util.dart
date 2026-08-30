import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/export.dart';

/// RSA 工具：与服务端（Python `PKCS1_v1_5` / 前端 JSEncrypt）保持一致的加密方式。
///
/// 服务端 `/auth/publicKey` 返回的是 PEM 主体（无头尾，可能含换行），
/// 其格式为 **SPKI**（SubjectPublicKeyInfo，对应 `-----BEGIN PUBLIC KEY-----`）。
///
/// 说明：pointycastle 并未提供 PEM 公钥解析器，因此这里用其 ASN.1 能力
/// 自行解析 DER，取出模数与指数构造 [RSAPublicKey]。
class RsaUtil {
  const RsaUtil._();

  /// 使用 RSA / PKCS#1 v1.5 加密明文，输出 Base64 字符串。
  static String encryptToBase64(String plainText, String publicKeyBase64) {
    final publicKey = parseSpkiPublicKey(publicKeyBase64);

    // PKCS1Encoding(RSAEngine()) = PKCS#1 v1.5（非 OAEP），与服务端一致
    final cipher = PKCS1Encoding(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));

    final encrypted =
        cipher.process(Uint8List.fromList(utf8.encode(plainText)));
    return base64.encode(encrypted);
  }

  /// 解析 SPKI 格式的 RSA 公钥。
  ///
  /// DER 结构：
  /// ```
  /// SEQUENCE {                                  // SubjectPublicKeyInfo
  ///   SEQUENCE { OID rsaEncryption, NULL }      // AlgorithmIdentifier
  ///   BIT STRING {                              // subjectPublicKey
  ///     SEQUENCE { modulus INTEGER, publicExponent INTEGER }
  ///   }
  /// }
  /// ```
  static RSAPublicKey parseSpkiPublicKey(String pemOrBase64) {
    final cleaned = pemOrBase64
        .replaceAll(RegExp(r'-----[A-Za-z ]+-----'), '')
        .replaceAll(RegExp(r'\s+'), '');

    Uint8List der;
    try {
      der = base64.decode(cleaned);
    } catch (_) {
      throw const FormatException('公钥解析失败：不是合法的 Base64 内容');
    }

    // 1) 外层 SubjectPublicKeyInfo
    final spkiObject = ASN1Parser(der).nextObject();
    if (spkiObject is! ASN1Sequence) {
      throw const FormatException('公钥解析失败：外层不是 DER SEQUENCE');
    }
    final spkiElements = spkiObject.elements;
    if (spkiElements == null || spkiElements.length < 2) {
      throw const FormatException('公钥解析失败：SubjectPublicKeyInfo 结构不完整');
    }

    // 2) 取 BIT STRING，其负载为内层 RSAPublicKey 的 DER
    final bitString = spkiElements[1];
    if (bitString is! ASN1BitString) {
      throw const FormatException('公钥解析失败：subjectPublicKey 不是 BIT STRING');
    }
    final inner = bitString.stringValues;
    if (inner == null || inner.isEmpty) {
      throw const FormatException('公钥解析失败：subjectPublicKey 内容为空');
    }

    // 3) 内层 RSAPublicKey = SEQUENCE { modulus, publicExponent }
    final rsaObject = ASN1Parser(Uint8List.fromList(inner)).nextObject();
    if (rsaObject is! ASN1Sequence) {
      throw const FormatException('公钥解析失败：内层不是 RSAPublicKey SEQUENCE');
    }
    final rsaElements = rsaObject.elements;
    if (rsaElements == null || rsaElements.length < 2) {
      throw const FormatException('公钥解析失败：RSA 公钥缺少模数或指数');
    }
    if (rsaElements[0] is! ASN1Integer || rsaElements[1] is! ASN1Integer) {
      throw const FormatException('公钥解析失败：模数/指数不是 INTEGER');
    }

    final modulus = (rsaElements[0] as ASN1Integer).integer;
    final exponent = (rsaElements[1] as ASN1Integer).integer;
    if (modulus == null || exponent == null) {
      throw const FormatException('公钥解析失败：模数或指数为空');
    }

    return RSAPublicKey(modulus, exponent);
  }
}
