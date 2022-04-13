part of 'dismissible_page.dart';

class MultiAxisDismissiblePage extends StatefulWidget {
  const MultiAxisDismissiblePage({
    required this.child,
    required this.onDismissed,
    required this.isFullScreen,
    required this.backgroundColor,
    required this.direction,
    required this.dismissThresholds,
    required this.dragStartBehavior,
    required this.dragSensitivity,
    required this.minRadius,
    required this.minScale,
    required this.maxRadius,
    required this.maxTransformValue,
    required this.startingOpacity,
    required this.onDragStart,
    required this.onDragEnd,
    required this.onDragUpdate,
    required this.reverseDuration,
    required this.behavior,
    required this.contentPadding,
    Key? key,
  }) : super(key: key);

  final double startingOpacity;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;
  final VoidCallback onDismissed;
  final ValueChanged<double>? onDragUpdate;
  final bool isFullScreen;
  final double minScale;
  final double minRadius;
  final double maxRadius;
  final double maxTransformValue;
  final Widget child;
  final Color backgroundColor;
  final DismissiblePageDismissDirection direction;
  final Map<DismissiblePageDismissDirection, double> dismissThresholds;
  final double dragSensitivity;
  final DragStartBehavior dragStartBehavior;
  final Duration reverseDuration;
  final HitTestBehavior behavior;
  final EdgeInsetsGeometry contentPadding;

  @protected
  MultiDragGestureRecognizer createRecognizer(
      GestureMultiDragStartCallback onStart,
      ) {
    return ImmediateMultiDragGestureRecognizer()..onStart = onStart;
  }

  @override
  _MultiAxisDismissiblePageState createState() =>
      _MultiAxisDismissiblePageState();
}

class _MultiAxisDismissiblePageState extends State<MultiAxisDismissiblePage>
    with Drag, SingleTickerProviderStateMixin {
  late final GestureRecognizer _recognizer;
  late final AnimationController _moveController;
  late final ValueNotifier<DismissiblePageDragUpdateDetails> _offsetNotifier;

  Offset _startOffset = Offset.zero;
  int _activeCount = 0;
  bool _dragUnderway = false;

  @override
  void initState() {
    super.initState();
    final initialDetails = DismissiblePageDragUpdateDetails(
      radius: widget.minRadius,
      opacity: widget.startingOpacity,
    );
    _offsetNotifier = ValueNotifier(initialDetails);
    _moveController =
        AnimationController(duration: widget.reverseDuration, vsync: this);
    _moveController.addStatusListener(statusListener);
    _moveController.addListener(animationListener);
    _recognizer = widget.createRecognizer(_startDrag);
    _offsetNotifier.addListener(_offsetListener);
  }

  void animationListener() {
    final offset = Offset.lerp(
      _offsetNotifier.value.offset,
      Offset.zero,
      Curves.easeInOut.transform(_moveController.value),
    )!;
    _updateOffset(offset);
  }

  void _updateOffset(Offset offset) {
    final k = overallDrag(offset);
    _offsetNotifier.value = DismissiblePageDragUpdateDetails(
      offset: offset,
      overallDragValue: k,
      radius: lerpDouble(widget.minRadius, widget.maxRadius, k)!,
      opacity: (widget.startingOpacity - k).clamp(.0, 1.0),
      scale: lerpDouble(1, widget.minScale, k)!,
    );
  }

  void _offsetListener() {
    // widget.onDragUpdate?.call(overallDrag());
  }

  void statusListener(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.onDragEnd?.call();
      _moveController.value = 0;
    }
  }

  double overallDrag([Offset? offset]) {
    final _offset = offset ?? _offsetNotifier.value.offset;
    final size = MediaQuery.of(context).size;
    final distanceOffset = _offset - Offset.zero;
    final w = distanceOffset.dx.abs() / size.width;
    final h = distanceOffset.dy.abs() / size.height;
    return max(w, h);
  }

  Drag? _startDrag(Offset position) {
    widget.onDragStart?.call();
    if (_activeCount > 1) return null;
    _dragUnderway = true;
    final renderObject = context.findRenderObject()! as RenderBox;
    _startOffset = renderObject.globalToLocal(position);
    return this;
  }

  void _routePointer(PointerDownEvent event) {
    ++_activeCount;
    if (_activeCount > 1) return;
    _recognizer.addPointer(event);
  }

  @override
  void update(DragUpdateDetails details) {
    if (_activeCount > 1) return;
    _updateOffset(
      (details.globalPosition - _startOffset) * widget.dragSensitivity,
    );
  }

  @override
  void cancel() => _dragUnderway = false;

  @override
  void end(DragEndDetails details) {
    if (!_dragUnderway) return;
    _dragUnderway = false;
    final shouldDismiss = overallDrag() >
        (widget.dismissThresholds[DismissiblePageDismissDirection.multi] ??
            _kDismissThreshold);
    if (shouldDismiss) {
      widget.onDismissed();
    } else {
      _moveController.animateTo(1);
    }
  }

  void _disposeRecognizerIfInactive() {
    if (_activeCount > 0) return;
    _recognizer.dispose();
  }

  @override
  void dispose() {
    _disposeRecognizerIfInactive();
    _moveController.dispose();
    _offsetNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = ValueListenableBuilder<DismissiblePageDragUpdateDetails>(
      valueListenable: _offsetNotifier,
      child: widget.child,
      builder: (_, DismissiblePageDragUpdateDetails details, Widget? child) {
        final backgroundColor = widget.backgroundColor == Colors.transparent
            ? Colors.transparent
            : widget.backgroundColor.withOpacity(details.opacity);
        return Container(
          padding: widget.contentPadding,
          color: backgroundColor,
          child: Transform(
            transform: Matrix4.identity()
              ..translate(details.offset.dx, details.offset.dy)
              ..scale(details.scale, details.scale),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(details.radius),
              child: child,
            ),
          ),
        );
      },
    );

    return Listener(
      onPointerDown: _routePointer,
      onPointerUp: (_) => --_activeCount,
      behavior: widget.behavior,
      child: content,
    );
  }
}
