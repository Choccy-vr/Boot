import 'package:flutter/material.dart';

class DeferredPage extends StatefulWidget {
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
  State<DeferredPage> createState() => _DeferredPageState();
}

class _DeferredPageState extends State<DeferredPage> {
  late Future<void> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = widget.loadLibrary();
  }

  @override
  void didUpdateWidget(covariant DeferredPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loadLibrary != widget.loadLibrary) {
      _loadFuture = widget.loadLibrary();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return widget.placeholder ?? const _DefaultDeferredLoading();
        }
        return widget.buildPage(context);
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
