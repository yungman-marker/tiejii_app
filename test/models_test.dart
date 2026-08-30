import 'package:flutter_test/flutter_test.dart';
import 'package:tiejii_app/data/models/models.dart';

/// 用真实接口返回样例验证解析逻辑（样例取自 2026-08-29 实测响应）。
void main() {
  group('UserProfile.fromJson（GET /system/user/getInfo）', () {
    test('解析嵌套 user 字段', () {
      final profile = UserProfile.fromJson(<String, dynamic>{
        'enterprise': <String, dynamic>{'name': 'crcc'},
        'roles': <String>['普通用户'],
        'user': <String, dynamic>{
          'userName': 'test1234',
          'nickName': 'test1234',
          'avatar': '',
        },
      });

      expect(profile.userName, 'test1234');
      expect(profile.nickName, 'test1234');
      expect(profile.displayName, 'test1234');
      expect(profile.enterprise, isNull); // enterprise 是 Map，不是 String
    });

    test('无 user 字段时按扁平结构解析', () {
      final profile =
          UserProfile.fromJson(<String, dynamic>{'userName': 'abc'});
      expect(profile.userName, 'abc');
      expect(profile.displayName, 'abc');
    });

    test('字段缺失时不抛异常', () {
      final profile = UserProfile.fromJson(<String, dynamic>{});
      expect(profile.userName, '');
      expect(profile.displayName, '');
    });
  });

  group('ChatModel.fromJson（POST /ai/chat/model/list）', () {
    test('解析能力标记：图片 / 思考 / 计费', () {
      final model = ChatModel.fromJson(<String, dynamic>{
        'id': '2090406911492481025',
        'chatModelCode': 'Qwen3.8',
        'name': 'Qwen3.8-chat',
        'feeType': 'charge',
        'inputModel': <String>['text', 'image'],
        'supportThinking': true,
      });

      expect(model.id, '2090406911492481025');
      expect(model.code, 'Qwen3.8');
      expect(model.supportsImage, isTrue);
      expect(model.supportThinking, isTrue);
      expect(model.isCharge, isTrue);
    });

    test('不支持图片的模型', () {
      final model = ChatModel.fromJson(<String, dynamic>{
        'id': '2',
        'chatModelCode': 'TJ1.0-multi',
        'inputModel': <String>['text'],
        'feeType': 'free',
      });

      expect(model.supportsImage, isFalse);
      expect(model.isCharge, isFalse);
      expect(model.name, 'TJ1.0-multi'); // 无 name 时回退为 code
    });
  });

  group('ChatMessage', () {
    test('toRequestJson 输出 role/content', () {
      final message =
          ChatMessage(id: 'x', role: ChatRole.user, content: '你好');
      expect(message.toRequestJson(),
          <String, String>{'role': 'user', 'content': '你好'});
      expect(message.isUser, isTrue);
    });

    test('助手消息 role 为 assistant', () {
      final message = ChatMessage(id: 'y', role: ChatRole.assistant);
      expect(message.toRequestJson()['role'], 'assistant');
      expect(message.isUser, isFalse);
    });
  });

  group('SessionSummary.fromJson（/ai/chat/his/record/list）', () {
    test('解析会话条目', () {
      final session = SessionSummary.fromJson(<String, dynamic>{
        'chatSessionId': '2093248885622128640',
        'titleName': '现在新疆是几点',
        'createTime': '2026-08-28 16:06:40',
        'chatModelCode': 'Qwen3.8',
        'usedKnowledge': false,
      });

      expect(session.sessionId, '2093248885622128640');
      expect(session.title, '现在新疆是几点');
      expect(session.usedKnowledge, isFalse);
    });
  });
}
