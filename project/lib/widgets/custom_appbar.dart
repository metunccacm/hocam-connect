import 'package:flutter/material.dart';

/// It can be used in any Scaffold:
/// Example:
///   appBar: HCAppBar(title: 'Settings', actions: [...])

class HCAppBar extends StatelessWidget implements PreferredSizeWidget {
  const HCAppBar({
    super.key,
    this.title,
    this.titleStyle,
    this.titleWidget,
    this.centerTitle = true,
    this.leading,
    this.actions,
    this.backgroundColor,
    this.elevation,
    this.automaticallyImplyLeading,
  });

  final String? title;
  final TextStyle? titleStyle;
  final Widget? titleWidget;
  final bool centerTitle;
  final Widget? leading;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final double? elevation;
  final bool? automaticallyImplyLeading;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: titleWidget ??
          (title != null ? Text(title!, style: titleStyle) : null),
      centerTitle: centerTitle,
      leading: leading,
      actions: actions,
      backgroundColor: backgroundColor,
      elevation: elevation,
      automaticallyImplyLeading: automaticallyImplyLeading ?? true,
    );
  }
}

/// Additional wrapper to scaffolds with HCAppBar.
///
/// AppScaffold = Scaffold + HCAppBar
///
/// Example:
///   return AppScaffold(
///     title: 'Settings',
///     body: ListView(...),
///   );
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    this.title,
    this.actions,
    required this.body,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.centerTitle = true,
  });

  final String? title;
  final List<Widget>? actions;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool centerTitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          HCAppBar(title: title, actions: actions, centerTitle: centerTitle),
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
