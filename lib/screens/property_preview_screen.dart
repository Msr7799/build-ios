import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/app_provider.dart';
import '../widgets/channel_badge.dart';

class PropertyPreviewScreen extends StatefulWidget {
  final Map<String, dynamic> card;

  const PropertyPreviewScreen({super.key, required this.card});

  @override
  State<PropertyPreviewScreen> createState() => _PropertyPreviewScreenState();
}

class _PropertyPreviewScreenState extends State<PropertyPreviewScreen> {
  int _currentImageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final isRtl = prov.isRtl;
    final card = widget.card;
    
    final name = (card['unitName'] ?? '') as String;
    final images = List<String>.from(card['images'] ?? []);
    final channels = List<String>.from(card['channels'] ?? []);
    final address = (card['address'] ?? '') as String;
    final rate = card['defaultRate'];
    final currency = (card['currency'] ?? 'BHD') as String;
    final guestCapacity = (card['guestCapacity'] ?? '') as String;
    final code = (card['code'] ?? '') as String;
    final snapshot = card['snapshot'] as Map<String, dynamic>?;
    final highlights = (card['propertyHighlights'] ?? '') as String;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            // Sliver App Bar with Image Carousel
            SliverAppBar(
              expandedHeight: 300,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (images.isNotEmpty)
                      PageView.builder(
                        itemCount: images.length,
                        onPageChanged: (index) =>
                            setState(() => _currentImageIndex = index),
                        itemBuilder: (context, index) {
                          return CachedNetworkImage(
                            imageUrl: images[index],
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: AppTheme.surface,
                              child: const Center(
                                  child: CircularProgressIndicator()),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: Colors.grey[200],
                              child: const Icon(Icons.error_outline,
                                  color: Colors.grey),
                            ),
                          );
                        },
                      )
                    else
                      Container(
                        color: Colors.grey[200],
                        child: Icon(Icons.image_not_supported,
                            size: 64, color: Colors.grey[400]),
                      ),
                    
                    // Gradient
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.7),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Image Counter
                    if (images.length > 1)
                      Positioned(
                        bottom: 16,
                        right: isRtl ? null : 16,
                        left: isRtl ? 16 : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_currentImageIndex + 1} / ${images.length}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              leading: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                ),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                if (channels.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      child: Wrap(
                        spacing: 4,
                        children: channels.map((ch) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.channelColor(ch),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            ch,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )).toList(),
                      ),
                    ),
                  ),
              ],
            ),

            // Content Body
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and Code
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                              height: 1.2,
                            ),
                          ),
                        ),
                        if (code.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Text(
                              code,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textSecondary),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Price
                    if (rate != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                           const Icon(Icons.monetization_on_outlined, size: 18, color: AppTheme.accent),
                           const SizedBox(width: 8),
                           Text(
                             '$rate $currency',
                             style: const TextStyle(
                               fontSize: 16,
                               fontWeight: FontWeight.bold,
                               color: AppTheme.accent,
                             ),
                           ),
                           Text(
                             isRtl ? ' / ليلة' : ' / night',
                             style: const TextStyle(
                               fontSize: 12,
                               color: AppTheme.accent,
                             ),
                           ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Stats
                    if (snapshot != null) ...[
                      Row(
                        children: [
                          _StatCard(
                            icon: Icons.login_rounded,
                            value: '${snapshot['checkins48h'] ?? 0}',
                            label: isRtl ? 'دخول (48س)' : 'In (48h)',
                            color: AppTheme.success,
                          ),
                          const SizedBox(width: 12),
                          _StatCard(
                            icon: Icons.logout_rounded,
                            value: '${snapshot['checkouts48h'] ?? 0}',
                            label: isRtl ? 'خروج (48س)' : 'Out (48h)',
                            color: AppTheme.warning,
                          ),
                          const SizedBox(width: 12),
                          _StatCard(
                            icon: Icons.message_outlined,
                            value: '${snapshot['guestMessagesCount'] ?? 0}',
                            label: isRtl ? 'رسائل' : 'Messages',
                            color: AppTheme.accent,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Info Row (Address, Capacity)
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    _InfoRow(
                      icon: Icons.location_on_outlined,
                      label: isRtl ? 'الموقع' : 'Location',
                      value: address.isNotEmpty ? address : (isRtl ? 'غير محدد' : 'Not specified'),
                    ),
                    const SizedBox(height: 12),
                    _InfoRow(
                      icon: Icons.people_outline_rounded,
                      label: isRtl ? 'السعة' : 'Capacity',
                      value: guestCapacity.isNotEmpty ? '$guestCapacity ${isRtl ? 'ضيوف' : 'guests'}' : (isRtl ? 'غير محدد' : 'Not specified'),
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),

                    // Highlights
                    if (highlights.isNotEmpty) ...[
                      Text(
                        isRtl ? 'مميزات العقار' : 'Property Highlights',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: highlights.split('\n').where((h) => h.isNotEmpty).map((h) => Chip(
                          label: Text(h, style: const TextStyle(fontSize: 12)),
                          backgroundColor: AppTheme.surface,
                          side: BorderSide.none,
                          visualDensity: VisualDensity.compact,
                        )).toList(),
                      ),
                       const SizedBox(height: 24),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppTheme.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
