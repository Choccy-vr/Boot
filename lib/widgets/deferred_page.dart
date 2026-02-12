import 'package:flutter/material.dart';

class DeferredPage extends StatelessWidget {
  const DeferredPage({
    super.key,
    required this.loadLibrary,
    required this.buildPage,
    this.placeholder,
  });

  final Future<void> Function() loadLibrary;
  final WidgetBuilder buildPage;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: loadLibrary(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return placeholder ?? const _DefaultDeferredLoading();
        }
        return buildPage(context);
      },
    );
  }
}

class _DefaultDeferredLoading extends StatelessWidget {
  const _DefaultDeferredLoading();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Center(
        child: CircularProgressIndicator(color: colorScheme.primary),
      ),
    );
  }
}
