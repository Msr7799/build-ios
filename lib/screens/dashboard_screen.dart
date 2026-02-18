import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/app_theme.dart';
import '../providers/app_provider.dart';
import '../widgets/channel_badge.dart';
import 'property_preview_screen.dart';
import 'notes_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Map<String, dynamic>> _cards = [];
  List<dynamic> _recentNotes = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final prov = context.read<AppProvider>();
      final dashboardData = await prov.api.getDashboard();
      
      // Fetch recent notes (unresolved)
      final notesData = await prov.api.getNotes(isResolved: false);
      
      setState(() {
         _cards = List<Map<String, dynamic>>.from(dashboardData['cards'] ?? []);
         _recentNotes = notesData.take(3).toList();
      });
    } catch (e) {
      debugPrint('Dashboard error: $e');
      setState(() => _error = e.toString());
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final isRtl = prov.isRtl;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isRtl ? 'لوحة التحكم' : 'Dashboard',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isRtl
                                    ? '${_cards.length} وحدة نشطة'
                                    : '${_cards.length} active units',
                                style: const TextStyle(
                                    fontSize: 13, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: prov.syncing ? null : () => prov.syncAll(),
                          icon: prov.syncing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.sync_rounded, size: 18),
                          label: Text(isRtl ? 'مزامنة' : 'Sync'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.accent,
                          ),
                        ),
                      ],
                    ),
                    if (prov.syncMsg != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          prov.syncMsg!,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ),
                    if (_error != null)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.danger.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, size: 16, color: AppTheme.danger),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(fontSize: 11, color: AppTheme.danger),
                                maxLines: 2, overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            // Notes Section Widget
            if (_recentNotes.isNotEmpty && !_loading)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isRtl ? 'الملاحظات الحديثة' : 'Recent Notes',
                             style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              // Navigate to Notes tab (index 10) or push screen
                              // Assuming we can switch tab or push
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const NotesScreen()));
                            },
                            child: Text(isRtl ? 'عرض الكل' : 'View All'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 140, // Height for horizontal scrolling cards
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _recentNotes.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final note = _recentNotes[index];
                            final priority = note['priority'] ?? 'NORMAL';
                            return Container(
                              width: 260,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.border),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          note['title'] ?? '',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (priority == 'URGENT' || priority == 'HIGH')
                                        Icon(Icons.priority_high, size: 16, color: priority == 'URGENT' ? Colors.red : Colors.orange),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    note['content'] ?? '',
                                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const Spacer(),
                                  Row(
                                    children: [
                                      if (note['unit'] != null)
                                        Expanded(
                                          child: Row(
                                            children: [
                                              const Icon(Icons.apartment, size: 12, color: AppTheme.textSecondary),
                                              const SizedBox(width: 4),
                                              Expanded(child: Text(note['unit']['name'] ?? '', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                            ],
                                          ),
                                        ),
                                      if ((note['attachments'] as List?)?.isNotEmpty == true)
                                         const Icon(Icons.attach_file, size: 14, color: AppTheme.accent),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            // Content
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_cards.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.home_work_outlined, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
                      const SizedBox(height: 16),
                      Text(
                        isRtl ? 'لا توجد وحدات بعد' : 'No units yet',
                        style: const TextStyle(fontSize: 16, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isRtl ? 'أضف وحدات من صفحة الوحدات' : 'Add units from the Units page',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _PropertyCard(card: _cards[i], isRtl: isRtl),
                    ),
                    childCount: _cards.length,
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }
}

class _PropertyCard extends StatelessWidget {
  final Map<String, dynamic> card;
  final bool isRtl;
  const _PropertyCard({required this.card, required this.isRtl});

  @override
  Widget build(BuildContext context) {
    final name = (card['unitName'] ?? '') as String;
    final images = List<String>.from(card['images'] ?? []);
    final channels = List<String>.from(card['channels'] ?? []);
    final address = (card['address'] ?? '') as String;
    final rate = card['defaultRate'];
    final currency = (card['currency'] ?? 'BHD') as String;
    final guestCapacity = (card['guestCapacity'] ?? '') as String;
    final code = (card['code'] ?? '') as String;
    final snapshot = card['snapshot'] as Map<String, dynamic>?;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PropertyPreviewScreen(card: card),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Image with overlay
          SizedBox(
            height: 180,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                images.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: images.first,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: AppTheme.surface,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (_, __, ___) => _buildPlaceholder(),
                      )
                    : _buildPlaceholder(),
                // Gradient overlay
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.5),
                        ],
                      ),
                    ),
                  ),
                ),
                // Channel badges top-right
                if (channels.isNotEmpty)
                  Positioned(
                    top: 10,
                    right: isRtl ? null : 10,
                    left: isRtl ? 10 : null,
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
                // Image count badge
                if (images.length > 1)
                  Positioned(
                    top: 10,
                    left: isRtl ? null : 10,
                    right: isRtl ? 10 : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.photo_library_rounded, size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            '${images.length}',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Rate on image bottom
                if (rate != null)
                  Positioned(
                    bottom: 10,
                    left: isRtl ? null : 14,
                    right: isRtl ? 14 : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$rate $currency / ${isRtl ? 'ليلة' : 'night'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Property Info
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name and code
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (code.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Text(
                          code,
                          style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                // Address and capacity
                if (address.isNotEmpty || guestCapacity.isNotEmpty)
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      if (address.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.textSecondary),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                address,
                                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      if (guestCapacity.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.people_outline_rounded, size: 14, color: AppTheme.textSecondary),
                            const SizedBox(width: 3),
                            Text(
                              guestCapacity,
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                    ],
                  ),
                // Snapshot stats
                if (snapshot != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        _statChip(
                          Icons.login_rounded,
                          '${snapshot['checkins48h'] ?? 0}',
                          isRtl ? 'دخول' : 'Check-in',
                          AppTheme.success,
                        ),
                        const SizedBox(width: 16),
                        _statChip(
                          Icons.logout_rounded,
                          '${snapshot['checkouts48h'] ?? 0}',
                          isRtl ? 'خروج' : 'Check-out',
                          AppTheme.warning,
                        ),
                        const SizedBox(width: 16),
                        _statChip(
                          Icons.message_outlined,
                          '${snapshot['guestMessagesCount'] ?? 0}',
                          isRtl ? 'رسائل' : 'Messages',
                          AppTheme.accent,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFFE8ECF1),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.home_work_rounded, size: 48, color: AppTheme.textSecondary.withValues(alpha: 0.3)),
            const SizedBox(height: 6),
            Text(
              isRtl ? 'لا توجد صورة' : 'No image',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
              Text(label, style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}
