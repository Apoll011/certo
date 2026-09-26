import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medication_reminder/ai/ai.dart';
import 'package:medication_reminder/models/medication.dart';
import 'package:medication_reminder/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppState state;
  late AiToolRegistry registry;

  setUp(() {
    state = AppState();
    // Pre-populate with known test medications
    state.medications.clear();
    state.takenIds.clear();

    state.medications.addAll([
      Medication(
        id: 'med-1',
        name: 'Amoxicillin',
        dosage: '500 mg',
        instruction: 'After breakfast',
        category: 'Antibiotic',
        notes: 'Take with food',
        times: ['08:00', '20:00'],
        pillColorIndex: 1,
        status: MedicationStatus.active,
        startedAt: DateTime(2026, 1, 1),
        frequencyDays: 1,
      ),
      Medication(
        id: 'med-2',
        name: 'Lisinopril',
        dosage: '10 mg',
        instruction: 'In the morning',
        category: 'Blood pressure',
        notes: '',
        times: ['09:00'],
        pillColorIndex: 2,
        status: MedicationStatus.paused,
        startedAt: DateTime(2026, 1, 1),
        frequencyDays: 1,
      ),
    ]);

    registry = AiToolRegistry.withMedicationTools(
      state,
      clock: () => DateTime(2026, 1, 1, 8, 2), // 08:02 AM
    );
  });

  group('Tool Spec Compliance (OpenAI & MCP)', () {
    test('OpenAI tool schema matches specification', () {
      final openAiTools = registry.toOpenAiTools();
      expect(openAiTools.isNotEmpty, isTrue);

      final listTool = openAiTools.firstWhere(
        (t) => (t['function'] as Map)['name'] == 'list_medications',
      );
      expect(listTool['type'], 'function');
      final fn = listTool['function'] as Map;
      expect(fn['name'], 'list_medications');
      expect(fn['parameters'], isA<Map>());
      expect(fn['parameters']['type'], 'object');
    });

    test('MCP tool schema matches inputSchema specification', () {
      final mcpTools = registry.toMcpTools();
      expect(mcpTools.isNotEmpty, isTrue);

      final listTool = mcpTools.firstWhere(
        (t) => t['name'] == 'list_medications',
      );
      expect(listTool['name'], 'list_medications');
      expect(listTool['inputSchema'], isA<Map>());
      expect(listTool['inputSchema']['type'], 'object');
    });
  });

  group('Medication Tools Execution', () {
    test('list_medications filters active by default', () async {
      final res = await registry.execute('list_medications', {});
      expect(res.success, isTrue);
      final data = res.data as Map;
      expect(data['count'], 1);
      final meds = data['medications'] as List;
      expect(meds.first['name'], 'Amoxicillin');
    });

    test('list_medications can filter by status and query', () async {
      final res = await registry.execute('list_medications', {
        'status': 'all',
        'query': 'lisino',
      });
      expect(res.success, isTrue);
      final data = res.data as Map;
      expect(data['count'], 1);
      final meds = data['medications'] as List;
      expect(meds.first['name'], 'Lisinopril');
    });

    test('get_medication_details retrieves by name or id', () async {
      final res = await registry.execute('get_medication_details', {
        'name': 'amoxicillin',
      });
      expect(res.success, isTrue);
      final data = res.data as Map;
      expect(data['id'], 'med-1');
      expect(data['dosage'], '500 mg');
    });

    test('get_next_medications detects due doses and upcoming schedule', () async {
      // Clock is set to 2026-01-01 08:02 AM.
      // Amoxicillin has 08:00 dose which is within 10 min lookback!
      final res = await registry.execute('get_next_medications', {
        'hours_ahead': 24,
      });
      expect(res.success, isTrue);
      final data = res.data as Map;
      expect(data['due_now_count'], greaterThanOrEqualTo(1));
      final dueList = data['due_now'] as List;
      expect(dueList.any((d) => d['medication_name'] == 'Amoxicillin'), isTrue);
    });

    test('create_medication creates a new medication in state', () async {
      final res = await registry.execute('create_medication', {
        'name': 'Metformin',
        'dosage': '850 mg',
        'times': ['08:00', '20:00'],
        'instruction': 'With meals',
        'category': 'Diabetes',
      });

      expect(res.success, isTrue);
      final data = res.data as Map;
      final med = data['medication'] as Map;
      expect(med['name'], 'Metformin');
      expect(state.medications.any((m) => m.name == 'Metformin'), isTrue);
    });

    test('update_medication modifies fields', () async {
      final res = await registry.execute('update_medication', {
        'name': 'Amoxicillin',
        'dosage': '1000 mg',
        'instruction': 'Take after dinner',
      });

      expect(res.success, isTrue);
      final updated = state.medicationById('med-1');
      expect(updated?.dosage, '1000 mg');
      expect(updated?.instruction, 'Take after dinner');
    });

    test('delete_medication removes medication', () async {
      final res = await registry.execute('delete_medication', {
        'name': 'Amoxicillin',
      });

      expect(res.success, isTrue);
      expect(state.medicationById('med-1'), isNull);
    });

    test('mark_medication_taken toggles adherence status', () async {
      expect(state.isTaken('med-1'), isFalse);

      final res1 = await registry.execute('mark_medication_taken', {
        'name': 'Amoxicillin',
        'taken': true,
      });
      expect(res1.success, isTrue);
      expect(state.isTaken('med-1'), isTrue);

      final res2 = await registry.execute('mark_medication_taken', {
        'name': 'Amoxicillin',
        'taken': false,
      });
      expect(res2.success, isTrue);
      expect(state.isTaken('med-1'), isFalse);
    });

    test('snooze_medication snoozes alarm', () async {
      final res = await registry.execute('snooze_medication', {
        'name': 'Amoxicillin',
        'minutes': 15,
      });
      expect(res.success, isTrue);
      expect(state.snoozedUntilFor('med-1'), isNotNull);
    });

    test('handles JSON string arguments automatically', () async {
      final jsonArgs = jsonEncode({'status': 'all'});
      final res = await registry.execute('list_medications', jsonArgs);
      expect(res.success, isTrue);
      final data = res.data as Map;
      expect(data['count'], 2);
    });
  });

  group('AI Assistant Service Loop', () {
    test('executes autonomous tool calling loop with mock HTTP client', () async {
      int requestCount = 0;

      final mockClient = MockClient((request) async {
        requestCount++;
        final reqBody = jsonDecode(request.body) as Map<String, dynamic>;
        final messages = reqBody['messages'] as List;

        if (requestCount == 1) {
          // First turn: assistant responds with a tool call to list_medications
          expect(reqBody['tools'], isNotNull);
          return http.Response(
            jsonEncode({
              'id': 'chatcmpl-123',
              'choices': [
                {
                  'index': 0,
                  'finish_reason': 'tool_calls',
                  'message': {
                    'role': 'assistant',
                    'content': null,
                    'tool_calls': [
                      {
                        'id': 'call_1',
                        'type': 'function',
                        'function': {
                          'name': 'list_medications',
                          'arguments': jsonEncode({'status': 'active'}),
                        },
                      },
                    ],
                  },
                },
              ],
            }),
            200,
          );
        } else {
          // Second turn: should have tool response in history, returns final text
          final lastMsg = messages.last as Map;
          expect(lastMsg['role'], 'tool');
          expect(lastMsg['tool_call_id'], 'call_1');

          return http.Response(
            jsonEncode({
              'id': 'chatcmpl-124',
              'choices': [
                {
                  'index': 0,
                  'finish_reason': 'stop',
                  'message': {
                    'role': 'assistant',
                    'content': 'You have 1 active medication: Amoxicillin 500 mg.',
                  },
                },
              ],
            }),
            200,
          );
        }
      });

      final openAiClient = OpenAiCompatibleClient(
        apiKey: 'test-key',
        httpClient: mockClient,
      );

      final assistant = AiAssistantService(
        client: openAiClient,
        tools: registry,
      );

      final events = <AiAssistantEvent>[];
      final result = await assistant.sendMessage(
        'What medications do I have?',
        onEvent: events.add,
      );

      expect(result.response, 'You have 1 active medication: Amoxicillin 500 mg.');
      expect(result.executedTools, ['list_medications']);
      expect(requestCount, 2);
      expect(events.any((e) => e is AiToolCallStartedEvent), isTrue);
      expect(events.any((e) => e is AiToolCallCompletedEvent), isTrue);
      expect(events.any((e) => e is AiResponseCompletedEvent), isTrue);
    });
  });

  group('Voice & ElevenLabs Integration (SpeakTool)', () {
    test('SpeakTool synthesizes spoken audio and invokes onSpeak callback', () async {
      String? spokenText;
      final speakTool = SpeakTool(
        onSpeak: (text) async {
          spokenText = text;
        },
      );

      final res = await speakTool.execute({'text': 'It is time for your Amoxicillin.'});
      expect(res.success, isTrue);
      expect(spokenText, 'It is time for your Amoxicillin.');

      final emptyRes = await speakTool.execute({'text': ''});
      expect(emptyRes.success, isFalse);
    });

    test('SpeakTool complies with OpenAI schema', () {
      final speakTool = SpeakTool();
      final schema = speakTool.toOpenAiTool();
      expect(schema['type'], 'function');
      final fn = schema['function'] as Map;
      expect(fn['name'], 'speak_to_user');
      expect((fn['parameters'] as Map)['required'], ['text']);
    });
  });

  group('Chat UI Tools (show_medication)', () {
    test('show_medication resolves by name and invokes onShowUi', () async {
      ChatUiAttachment? shown;
      final tool = ShowMedicationTool(
        state,
        onShowUi: (a) => shown = a,
      );

      final res = await tool.execute({
        'name': 'Amoxicillin',
        'badge': 'Next',
        'highlight': '8:00 AM · After breakfast',
        'caption': 'Here is your next dose',
      });

      expect(res.success, isTrue);
      expect(shown, isA<MedicationCardAttachment>());
      final card = shown! as MedicationCardAttachment;
      expect(card.name, 'Amoxicillin');
      expect(card.badge, 'Next');
      expect(card.highlight, '8:00 AM · After breakfast');
      expect(card.dosage, '500 mg');
      expect(card.pillColorIndex, 1);
    });

    test('show_medications lists active meds when names omitted', () async {
      ChatUiAttachment? shown;
      final tool = ShowMedicationsTool(
        state,
        onShowUi: (a) => shown = a,
      );

      final res = await tool.execute({
        'title': "Today's schedule",
        'badge': 'Today',
      });

      expect(res.success, isTrue);
      expect(shown, isA<MedicationListAttachment>());
      final list = shown! as MedicationListAttachment;
      expect(list.title, "Today's schedule");
      expect(list.items.length, 1); // only active Amoxicillin
      expect(list.items.first.name, 'Amoxicillin');
    });

    test('show_dose_status renders confirmation card', () async {
      ChatUiAttachment? shown;
      final tool = ShowDoseStatusTool(
        state,
        onShowUi: (a) => shown = a,
      );

      final res = await tool.execute({
        'name': 'Amoxicillin',
        'status_label': 'Marked as taken',
        'tone': 'success',
        'detail': 'Next dose at 8:00 PM',
      });

      expect(res.success, isTrue);
      expect(shown, isA<DoseStatusAttachment>());
      final card = shown! as DoseStatusAttachment;
      expect(card.medicationName, 'Amoxicillin');
      expect(card.statusLabel, 'Marked as taken');
      expect(card.tone, 'success');
    });

    test('withAllTools registers UI tools', () {
      final full = AiToolRegistry.withAllTools(state);
      expect(full.getTool('show_medication'), isNotNull);
      expect(full.getTool('show_medications'), isNotNull);
      expect(full.getTool('show_dose_status'), isNotNull);
    });
  });

  group('Vision & Visual Mode Tools', () {
    test('StartVisualModeTool triggers visual mode with scheduled context', () async {
      VisualModeRequest? capturedRequest;
      final startVisualTool = StartVisualModeTool(
        onStartVisualMode: (req) async {
          capturedRequest = req;
        },
      );

      final res = await startVisualTool.execute({
        'reason': 'User asking is this my medication',
        'expected_medication_name': 'Amoxicillin 500mg',
      });

      expect(res.success, isTrue);
      expect(capturedRequest?.expectedMedicationName, 'Amoxicillin 500mg');
    });

    test('ShowVisualVerificationResultTool handles confirmed match correctly', () async {
      VisualVerificationCardData? cardData;
      final showResultTool = ShowVisualVerificationResultTool(
        onShowResult: (data) => cardData = data,
      );

      final res = await showResultTool.execute({
        'status': 'confirmed_match',
        'identified_medication_name': 'Amoxicillin 500mg',
        'category': 'Antibiotic · Oral tablet',
        'message': 'This is your medication. It\'s scheduled for now.',
        'expected_medication_name': 'Amoxicillin 500mg',
        'next_dose_time': '9:00 AM',
        'next_dose_instruction': '1 tablet · After meal',
      });

      expect(res.success, isTrue);
      expect(cardData?.status, VisualVerificationStatus.confirmedMatch);
      expect(cardData?.canConfirm, isTrue);
      expect(cardData?.identifiedMedicationName, 'Amoxicillin 500mg');
    });

    test('ShowVisualVerificationResultTool handles confirmed mismatch correctly', () async {
      VisualVerificationCardData? cardData;
      final showResultTool = ShowVisualVerificationResultTool(
        onShowResult: (data) => cardData = data,
      );

      final res = await showResultTool.execute({
        'status': 'confirmed_mismatch',
        'expected_medication_name': 'Amoxicillin 500mg',
        'next_dose_instruction': '1 tablet · After meal',
      });

      expect(res.success, isTrue);
      expect(cardData?.status, VisualVerificationStatus.confirmedMismatch);
      expect(cardData?.canConfirm, isFalse);
    });

    test('ShowVisualVerificationResultTool handles uncertain safety state', () async {
      VisualVerificationCardData? cardData;
      final showResultTool = ShowVisualVerificationResultTool(
        onShowResult: (data) => cardData = data,
      );

      final res = await showResultTool.execute({
        'status': 'uncertain',
      });

      expect(res.success, isTrue);
      expect(cardData?.status, VisualVerificationStatus.uncertain);
      expect(cardData?.canConfirm, isFalse);
    });
  });

  group('Multimodal ChatMessage & Visual Verification Flow', () {
    test('ChatMessage formats image base64 correctly for OpenAI/DeepSeek Vision', () {
      final msg = ChatMessage.userWithImage(
        'Is this my medication?',
        imageBase64: 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
      );

      final json = msg.toJson();
      expect(json['role'], 'user');
      final parts = json['content'] as List;
      expect(parts.length, 2);
      expect(parts[0]['type'], 'text');
      expect(parts[0]['text'], 'Is this my medication?');
      expect(parts[1]['type'], 'image_url');
      expect((parts[1]['image_url'] as Map)['url'], startsWith('data:image/jpeg;base64,'));
      expect(msg.textContent, 'Is this my medication?');
    });

    test('AI Assistant handles image verification query with tools', () async {
      VisualVerificationCardData? displayedCard;
      String? spokenVoice;

      final fullRegistry = AiToolRegistry.withAllTools(
        state,
        onSpeak: (text) async => spokenVoice = text,
        onShowVisualResult: (data) => displayedCard = data,
      );

      int round = 0;
      final mockClient = MockClient((request) async {
        round++;
        if (round == 1) {
          // Model inspects the photo and invokes show_visual_verification_result
          return http.Response(
            jsonEncode({
              'id': 'chatcmpl-vis-1',
              'choices': [
                {
                  'index': 0,
                  'finish_reason': 'tool_calls',
                  'message': {
                    'role': 'assistant',
                    'content': null,
                    'tool_calls': [
                      {
                        'id': 'call_vis_1',
                        'type': 'function',
                        'function': {
                          'name': 'show_visual_verification_result',
                          'arguments': jsonEncode({
                            'status': 'confirmed_match',
                            'identified_medication_name': 'Amoxicillin 500mg',
                            'category': 'Antibiotic · Oral tablet',
                            'message': 'This is your medication. It\'s scheduled for now.',
                            'next_dose_time': '9:00 AM',
                            'next_dose_instruction': '1 tablet · After meal',
                          }),
                        },
                      },
                      {
                        'id': 'call_speak_1',
                        'type': 'function',
                        'function': {
                          'name': 'speak_to_user',
                          'arguments': jsonEncode({
                            'text': 'Yes, this is your Amoxicillin 500mg scheduled for now.',
                          }),
                        },
                      },
                    ],
                  },
                },
              ],
            }),
            200,
          );
        } else {
          return http.Response(
            jsonEncode({
              'id': 'chatcmpl-vis-2',
              'choices': [
                {
                  'index': 0,
                  'finish_reason': 'stop',
                  'message': {
                    'role': 'assistant',
                    'content': 'Verified: This is your Amoxicillin 500mg scheduled for now.',
                  },
                },
              ],
            }),
            200,
          );
        }
      });

      final openAiClient = OpenAiCompatibleClient(
        apiKey: 'test-key',
        httpClient: mockClient,
      );

      final assistant = AiAssistantService(
        client: openAiClient,
        tools: fullRegistry,
      );

      final result = await assistant.verifyMedicationImage(
        imageBase64: 'fake-photo-bytes',
        userPrompt: 'Is this my medication?',
      );

      expect(displayedCard?.status, VisualVerificationStatus.confirmedMatch);
      expect(displayedCard?.identifiedMedicationName, 'Amoxicillin 500mg');
      expect(spokenVoice, 'Yes, this is your Amoxicillin 500mg scheduled for now.');
      expect(result.executedTools, contains('show_visual_verification_result'));
      expect(result.executedTools, contains('speak_to_user'));
    });
  });
}

