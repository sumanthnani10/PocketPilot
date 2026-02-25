import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'accessibility_service.dart';

class GeminiService {
  final GenerativeModel _model;
  List<Content> _chatHistory = [];

  GeminiService(String apiKey)
      : _model = GenerativeModel(
          model: 'gemini-2.5-flash',
          apiKey: apiKey,
          systemInstruction: Content.system('''
You are PocketPilot, a mobile automation agent. 
You are given a task and the current Android UI tree in JSON format.
Your goal is to complete the task by returning ONE action at a time.
Use the tools provided to interact with the screen. 
Always observe the provided UI tree carefully to decide the next action.
You can ONLY take one action before the screen updates.
If the task is complete, call task_complete().
If you cannot proceed or need user help, call ask_help(reason).
'''),
          tools: [
            Tool(functionDeclarations: [
              FunctionDeclaration(
                'click',
                'Clicks a UI element using its node path.',
                Schema(SchemaType.object, properties: {
                  'path': Schema(SchemaType.string, description: 'The node path of the UI element to click.'),
                }, requiredProperties: ['path']),
              ),
              FunctionDeclaration(
                'scroll_forward',
                'Scrolls the screen forward (usually down or right) on a scrollable node.',
                Schema(SchemaType.object, properties: {
                  'path': Schema(SchemaType.string, description: 'The node path of the scrollable UI element.'),
                }, requiredProperties: ['path']),
              ),
              FunctionDeclaration(
                'scroll_backward',
                'Scrolls the screen backward (usually up or left) on a scrollable node.',
                Schema(SchemaType.object, properties: {
                  'path': Schema(SchemaType.string, description: 'The node path of the scrollable UI element.'),
                }, requiredProperties: ['path']),
              ),
              FunctionDeclaration(
                'set_text',
                'Types text into an editable UI element.',
                Schema(SchemaType.object, properties: {
                  'path': Schema(SchemaType.string, description: 'The node path of the UI element.'),
                  'text': Schema(SchemaType.string, description: 'The text to type.'),
                }, requiredProperties: ['path', 'text']),
              ),
              FunctionDeclaration(
                'global_action',
                'Performs a global action such as home, back or recents.',
                Schema(SchemaType.object, properties: {
                  'action': Schema(SchemaType.string, description: 'Action name: "home", "back", "recents".'),
                }, requiredProperties: ['action']),
              ),
              FunctionDeclaration(
                'tap_coordinate',
                'Taps at an x, y coordinate. Only use if a node cannot be clicked by path.',
                Schema(SchemaType.object, properties: {
                  'x': Schema(SchemaType.number, description: 'X coordinate.'),
                  'y': Schema(SchemaType.number, description: 'Y coordinate.'),
                }, requiredProperties: ['x', 'y']),
              ),
              FunctionDeclaration(
                'task_complete',
                'Signals that the given task is completed.',
                Schema(SchemaType.object, properties: {
                  'message': Schema(SchemaType.string, description: 'Optional success message.'),
                }),
              ),
              FunctionDeclaration(
                'ask_help',
                'Asks the user for help when you cannot proceed.',
                Schema(SchemaType.object, properties: {
                  'reason': Schema(SchemaType.string, description: 'Reason for needing help.'),
                }, requiredProperties: ['reason']),
              )
            ])
          ],
        );

  void startNewTask(String task) {
    _chatHistory = [
      Content.text('Task: $task\nNow I will provide you with the current UI tree.')
    ];
  }

  /// Sends the current screen tree and returns a log string describing what it decided to do.
  Future<String> step(Map<dynamic, dynamic> uiTree) async {
    // Convert UI tree to a compact JSON string.
    final String treeJson = jsonEncode(uiTree);
    
    _chatHistory.add(Content.text('Current UI Tree:\n$treeJson'));

    try {
      final response = await _model.generateContent(_chatHistory);
      
      if (response.functionCalls.isNotEmpty) {
        final functionCall = response.functionCalls.first;
        final String toolResult = await _executeFunctionCall(functionCall);
        
        // Feed the result back.
        _chatHistory.add(Content.model([functionCall]));
        _chatHistory.add(Content.functionResponse(functionCall.name, {'result': toolResult}));
        
        if (functionCall.name == 'task_complete') {
          return 'Task completed! ${functionCall.args["message"] ?? ""}';
        } else if (functionCall.name == 'ask_help') {
          return 'Need help: ${functionCall.args["reason"]}';
        }
        
        return 'Executed: ${functionCall.name} with ${functionCall.args} -> $toolResult';
      } else {
        // Did not return a function call, maybe it said something directly.
        _chatHistory.add(Content.model([TextPart(response.text ?? '')]));
        return 'Agent responded (no action): ${response.text}';
      }
    } catch (e) {
      return 'Error during Gemini step: $e';
    }
  }

  Future<String> _executeFunctionCall(FunctionCall call) async {
    try {
      if (call.name == 'click') {
        final path = call.args['path'] as String;
        final success = await AccessibilityService.performAction(path, 'click');
        return success ? 'clicked' : 'failed';
      } else if (call.name == 'scroll_forward') {
        final path = call.args['path'] as String;
        final success = await AccessibilityService.performAction(path, 'scroll_forward');
        return success ? 'scrolled_forward' : 'failed';
      } else if (call.name == 'scroll_backward') {
        final path = call.args['path'] as String;
        final success = await AccessibilityService.performAction(path, 'scroll_backward');
        return success ? 'scrolled_backward' : 'failed';
      } else if (call.name == 'set_text') {
        final path = call.args['path'] as String;
        final text = call.args['text'] as String;
        final success = await AccessibilityService.performAction(path, 'set_text', arg: text);
        return success ? 'text_set' : 'failed';
      } else if (call.name == 'global_action') {
        final action = call.args['action'] as String;
        final success = await AccessibilityService.performGlobalAction(action);
        return success ? 'global_action_done' : 'failed';
      } else if (call.name == 'tap_coordinate') {
        final x = (call.args['x'] as num).toDouble();
        final y = (call.args['y'] as num).toDouble();
        final success = await AccessibilityService.tapOnCoordinate(x, y);
        return success ? 'tapped_coordinate' : 'failed';
      } else if (call.name == 'task_complete') {
        return 'success';
      } else if (call.name == 'ask_help') {
        return 'help_requested';
      }
    } catch (e) {
      return 'exception: $e';
    }
    return 'unknown_command';
  }
}
