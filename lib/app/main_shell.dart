import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timeotalk/features/contacts/viewmodels/contacts_view_model.dart';
import 'package:timeotalk/features/contacts/views/contacts_view.dart';
import 'package:timeotalk/features/profile/viewmodels/profile_view_model.dart';
import 'package:timeotalk/features/profile/views/profile_view.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    this.initialIndex = 0,
    this.currentUserId,
    this.contactsViewModel,
    this.profileViewModel,
    super.key,
  });

  final int initialIndex;
  final String? currentUserId;
  final ContactsViewModel? contactsViewModel;
  final ProfileViewModel? profileViewModel;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _selectedIndex;
  late final List<bool> _visitedTabs;

  static const _tabs = [
    ShellTab(
      key: Key('tab-screen-inbox'),
      icon: Icons.chat_bubble_outline,
      selectedIcon: Icons.chat_bubble,
      iosIconName: 'message',
      iosSelectedIconName: 'message.fill',
      label: 'Inbox',
    ),
    ShellTab(
      key: Key('tab-screen-contacts'),
      icon: Icons.people_outline,
      selectedIcon: Icons.people,
      iosIconName: 'person.2',
      iosSelectedIconName: 'person.2.fill',
      label: 'Contacts',
    ),
    ShellTab(
      key: Key('tab-screen-profile'),
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      iosIconName: 'person.crop.circle',
      iosSelectedIconName: 'person.crop.circle.fill',
      label: 'Profile',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex.clamp(0, _tabs.length - 1);
    _visitedTabs = List<bool>.filled(_tabs.length, false);
    _visitedTabs[_selectedIndex] = true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: [
              _buildTabScreen(0),
              _buildTabScreen(1),
              _buildTabScreen(2),
            ],
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 12,
            child: SafeArea(top: false, child: _buildNavBar()),
          ),
        ],
      ),
    );
  }

  Widget _buildNavBar() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return NativeIosLiquidGlassNavBar(
        tabs: _tabs,
        selectedIndex: _selectedIndex,
        onSelected: _selectTab,
      );
    }

    return LiquidGlassNavBar(
      tabs: _tabs,
      selectedIndex: _selectedIndex,
      onSelected: _selectTab,
    );
  }

  void _selectTab(int index) {
    setState(() {
      _selectedIndex = index;
      _visitedTabs[index] = true;
    });
  }

  Widget _buildTabScreen(int index) {
    if (!_visitedTabs[index]) {
      return const SizedBox.shrink();
    }

    final tab = _tabs[index];
    if (tab.label == 'Contacts') {
      return ContactsView(
        key: tab.key,
        currentUserId: widget.currentUserId,
        viewModel: widget.contactsViewModel,
      );
    }

    if (tab.label == 'Profile') {
      return ProfileView(key: tab.key, viewModel: widget.profileViewModel);
    }

    return _BlankTabScreen(key: tab.key, title: tab.label);
  }
}

class NativeIosLiquidGlassNavBar extends StatefulWidget {
  const NativeIosLiquidGlassNavBar({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  static const viewType = 'timeotalk/native_glass_tab_bar';

  final List<ShellTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  State<NativeIosLiquidGlassNavBar> createState() =>
      _NativeIosLiquidGlassNavBarState();
}

class _NativeIosLiquidGlassNavBarState
    extends State<NativeIosLiquidGlassNavBar> {
  MethodChannel? _channel;

  @override
  void didUpdateWidget(covariant NativeIosLiquidGlassNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.selectedIndex != widget.selectedIndex) {
      unawaited(_setNativeSelectedIndex(widget.selectedIndex));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 74,
      child: UiKitView(
        viewType: NativeIosLiquidGlassNavBar.viewType,
        creationParams: {
          'selectedIndex': widget.selectedIndex,
          'tabs': [
            for (final tab in widget.tabs)
              {
                'label': tab.label,
                'iconName': tab.iosIconName,
                'selectedIconName': tab.iosSelectedIconName,
              },
          ],
        },
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _handlePlatformViewCreated,
      ),
    );
  }

  void _handlePlatformViewCreated(int viewId) {
    final channel = MethodChannel('timeotalk/native_glass_tab_bar_$viewId');
    channel.setMethodCallHandler(_handleNativeMethodCall);
    _channel = channel;
    unawaited(_setNativeSelectedIndex(widget.selectedIndex));
  }

  Future<dynamic> _handleNativeMethodCall(MethodCall call) async {
    if (call.method != 'onTabSelected') {
      throw MissingPluginException('Unknown method: ${call.method}');
    }

    final index = call.arguments;
    if (index is int && index >= 0 && index < widget.tabs.length) {
      widget.onSelected(index);
    }

    return null;
  }

  Future<void> _setNativeSelectedIndex(int index) async {
    try {
      await _channel?.invokeMethod<void>('setSelectedIndex', index);
    } on MissingPluginException {
      // The native view is not available in widget tests or non-iOS previews.
    }
  }
}

class LiquidGlassNavBar extends StatelessWidget {
  const LiquidGlassNavBar({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final List<ShellTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.62),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Row(
              children: [
                for (var index = 0; index < tabs.length; index++)
                  Expanded(
                    child: _LiquidGlassNavItem(
                      tab: tabs[index],
                      isSelected: index == selectedIndex,
                      onTap: () => onSelected(index),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LiquidGlassNavItem extends StatelessWidget {
  const _LiquidGlassNavItem({
    required this.tab,
    required this.isSelected,
    required this.onTap,
  });

  final ShellTab tab;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = isSelected
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;

    return Tooltip(
      message: tab.label,
      child: Semantics(
        label: tab.label,
        button: true,
        selected: isSelected,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            height: 52,
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primaryContainer.withValues(alpha: 0.74)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.72)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: Center(
              child: Icon(
                isSelected ? tab.selectedIcon : tab.icon,
                color: foreground,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BlankTabScreen extends StatelessWidget {
  const _BlankTabScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF9FAFB), Color(0xFFEFF4F7)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 112),
          child: Align(
            alignment: Alignment.topLeft,
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ShellTab {
  const ShellTab({
    required this.key,
    required this.icon,
    required this.selectedIcon,
    required this.iosIconName,
    required this.iosSelectedIconName,
    required this.label,
  });

  final Key key;
  final IconData icon;
  final IconData selectedIcon;
  final String iosIconName;
  final String iosSelectedIconName;
  final String label;
}
