import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Route categories for intelligent model selection
enum SimsarRouteCategory {
  propertyManagement,  // Property queries, bookings, calendar
  financialAnalysis,   // Revenue, expenses, reports
  contentGeneration,   // Creating descriptions, marketing
  generalChat,         // Casual conversation
  dataExtraction,      // Extracting structured data
}

/// AI Model definition with capabilities
class SimsarAIModel {
  final String id;
  final String name;
  final String description;
  final List<SimsarRouteCategory> specialties;
  final bool isDefault;
  final int priority;
  
  const SimsarAIModel({
    required this.id,
    required this.name,
    required this.description,
    required this.specialties,
    this.isDefault = false,
    this.priority = 0,
  });
}

class SimsarConfig {
  static String get provider => dotenv.env['SIMSAR_PROVIDER'] ?? 'huggingface';
  static String get apiKey => dotenv.env['SIMSAR_API_KEY'] ?? '';
  static String get defaultModel => dotenv.env['SIMSAR_MODEL'] ?? 'Qwen/Qwen3-235B-A22B-Instruct-2507';
  
  static bool get isConfigured => apiKey.isNotEmpty;
  
  static String get apiUrl {
    switch (provider) {
      case 'huggingface':
        return 'https://router.huggingface.co/v1/chat/completions';
      case 'openrouter':
        return 'https://openrouter.ai/api/v1/chat/completions';
      default:
        return 'https://router.huggingface.co/v1/chat/completions';
    }
  }
  
  static Map<String, String> get headers {
    return {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };
  }
  
  /// Available AI models with their specialties
  static const List<SimsarAIModel> availableModels = [
    SimsarAIModel(
      id: 'Qwen/Qwen3-235B-A22B-Instruct-2507',
      name: 'Qwen 3 235B',
      description: 'نموذج متعدد الاستخدامات للمحادثات والتحليل',
      specialties: [SimsarRouteCategory.propertyManagement, SimsarRouteCategory.generalChat],
      isDefault: true,
      priority: 100,
    ),
    SimsarAIModel(
      id: 'deepseek-ai/DeepSeek-V3.1',
      name: 'DeepSeek V3.1',
      description: 'ممتاز للتحليل المالي والبيانات',
      specialties: [SimsarRouteCategory.financialAnalysis, SimsarRouteCategory.dataExtraction],
      priority: 90,
    ),
    SimsarAIModel(
      id: 'moonshotai/Kimi-K2-Instruct-0905',
      name: 'Kimi K2',
      description: 'ممتاز لكتابة المحتوى والوصف',
      specialties: [SimsarRouteCategory.contentGeneration],
      priority: 85,
    ),
    SimsarAIModel(
      id: 'meta-llama/Llama-3.3-70B-Instruct',
      name: 'Llama 3.3 70B',
      description: 'نموذج سريع ودقيق',
      specialties: [SimsarRouteCategory.generalChat, SimsarRouteCategory.propertyManagement],
      priority: 80,
    ),
    SimsarAIModel(
      id: 'zai-org/GLM-4.6',
      name: 'GLM 4.6',
      description: 'ممتاز لاستخراج البيانات المنظمة',
      specialties: [SimsarRouteCategory.dataExtraction],
      priority: 75,
    ),
  ];
  
  /// Get the best model for a given query
  static String getModelForQuery(String query) {
    final category = _categorizeQuery(query);
    
    // Find models that specialize in this category
    final specialists = availableModels
        .where((m) => m.specialties.contains(category))
        .toList();
    
    if (specialists.isEmpty) {
      return defaultModel;
    }
    
    // Sort by priority and return the best
    specialists.sort((a, b) => b.priority.compareTo(a.priority));
    return specialists.first.id;
  }
  
  /// Categorize a query to determine the best model
  static SimsarRouteCategory _categorizeQuery(String query) {
    final q = query.toLowerCase();
    
    // Financial keywords
    final financialKeywords = [
      'إيراد', 'مصروف', 'ربح', 'خسارة', 'مالي', 'تقرير', 'إحصائ',
      'revenue', 'expense', 'profit', 'financial', 'report', 'statistics',
      'دخل', 'صافي', 'عمولة', 'ضريبة', 'رسوم', 'دفع', 'مدفوع',
    ];
    
    // Property management keywords
    final propertyKeywords = [
      'حجز', 'حجوزات', 'وحد', 'عقار', 'تقويم', 'متاح', 'محجوز',
      'booking', 'unit', 'property', 'calendar', 'available', 'booked',
      'ضيف', 'ليل', 'تسجيل', 'وصول', 'مغادرة', 'قادم',
    ];
    
    // Content generation keywords
    final contentKeywords = [
      'اكتب', 'صف', 'وصف', 'محتوى', 'نص', 'تسويق', 'إعلان',
      'write', 'describe', 'content', 'marketing', 'ad', 'text',
      'صياغة', 'تحرير', 'مراجعة',
    ];
    
    // Data extraction keywords
    final dataKeywords = [
      'استخرج', 'json', 'بيانات', 'جدول', 'قائمة', 'تصدير',
      'extract', 'data', 'table', 'list', 'export', 'csv',
    ];
    
    // Check each category
    for (final keyword in financialKeywords) {
      if (q.contains(keyword)) return SimsarRouteCategory.financialAnalysis;
    }
    
    for (final keyword in contentKeywords) {
      if (q.contains(keyword)) return SimsarRouteCategory.contentGeneration;
    }
    
    for (final keyword in dataKeywords) {
      if (q.contains(keyword)) return SimsarRouteCategory.dataExtraction;
    }
    
    for (final keyword in propertyKeywords) {
      if (q.contains(keyword)) return SimsarRouteCategory.propertyManagement;
    }
    
    return SimsarRouteCategory.generalChat;
  }
  
  /// Get model name by ID
  static String getModelName(String modelId) {
    final model = availableModels.where((m) => m.id == modelId).firstOrNull;
    return model?.name ?? modelId.split('/').last;
  }
  
  /// Dynamic system prompt with real data context
  static String getSystemPrompt(String dataContext) {
    return '''
أنت "سمسار" - مساعد ذكي متخصص في إدارة العقارات. أنت تعمل ضمن نظام PMS Lite لإدارة العقارات.

مهامك الأساسية:
1. الإجابة عن أي استفسار يخص العقارات والحجوزات والتقويم باستخدام البيانات الحقيقية المتاحة لك
2. تقديم ملخصات وتقارير دقيقة عن الوحدات والحجوزات
3. المساعدة في فهم البيانات المالية والمصروفات
4. تقديم نصائح عملية لتحسين إدارة العقارات

قواعد مهمة:
- استخدم البيانات الحقيقية المقدمة لك فقط، لا تختلق بيانات
- إذا لم تجد معلومة، قل ذلك بوضوح
- أجب بشكل مختصر ومفيد باللغة العربية
- استخدم التنسيق المناسب (قوائم، أرقام) لتسهيل القراءة
- عند ذكر التواريخ، استخدم صيغة يوم/شهر
- عند ذكر المبالغ، اذكر العملة

$dataContext
''';
  }
  
  /// Legacy system prompt for backward compatibility
  static const String systemPrompt = '''
أنت "سمسار" - مساعد ذكي متخصص في إدارة العقارات. أنت تعمل ضمن نظام PMS Lite لإدارة العقارات.

مهامك الأساسية:
1. الإجابة عن أي استفسار يخص العقارات والحجوزات والتقويم
2. تقديم ملخصات وتقارير عن الوحدات والحجوزات
3. المساعدة في فهم البيانات المالية والمصروفات
4. تقديم نصائح لتحسين إدارة العقارات

أجب بشكل مختصر ومفيد باللغة العربية.
''';
}
