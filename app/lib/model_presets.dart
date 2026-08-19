class ModelPreset {
  const ModelPreset({required this.id, required this.label, required this.model, required this.baseUrl, required this.hint});
  final String id;
  final String label;
  final String model;
  final String baseUrl;
  final String hint;
}

const modelPresets = <ModelPreset>[
  ModelPreset(
    id: 'gpt4o-mini',
    label: 'GPT-4o mini',
    model: 'gpt-4o-mini',
    baseUrl: 'https://api.openai.com/v1',
    hint: '便宜、JSON 稳，适合日常情景',
  ),
  ModelPreset(
    id: 'gpt4o',
    label: 'GPT-4o',
    model: 'gpt-4o',
    baseUrl: 'https://api.openai.com/v1',
    hint: '分析更细，成本更高',
  ),
  ModelPreset(
    id: 'deepseek',
    label: 'DeepSeek Chat',
    model: 'deepseek-chat',
    baseUrl: 'https://api.deepseek.com/v1',
    hint: '性价比高，OpenAI 兼容',
  ),
  ModelPreset(
    id: 'qwen',
    label: '通义千问 Plus',
    model: 'qwen-plus',
    baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    hint: '中文叙述较好',
  ),
  ModelPreset(
    id: 'openrouter',
    label: 'OpenRouter',
    model: 'anthropic/claude-3.5-sonnet',
    baseUrl: 'https://openrouter.ai/api/v1',
    hint: '一个 Key 换多家模型',
  ),
];
