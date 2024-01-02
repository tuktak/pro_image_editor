import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rounded_background_text/rounded_background_text.dart';

import '../models/i18n/i18n.dart';
import '../models/layer.dart';
import '../modules/paint_editor/utils/draw/draw_canvas.dart';
import '../modules/paint_editor/utils/paint_editor_enum.dart';
import 'dashed_border.dart';
import 'pro_image_editor_desktop_mode.dart';

/// A widget representing a layer within a design canvas.
class LayerWidget extends StatefulWidget {
  /// Data for the layer.
  final Layer layerData;

  /// Callback when a tap down event occurs.
  final Function() onTapDown;

  /// Callback when a tap up event occurs.
  final Function() onTapUp;

  /// Callback when a tap event occurs.
  final Function(Layer) onTap;

  /// Callback for removing the layer.
  final Function() onRemoveTap;

  /// Padding for positioning the layer within the canvas.
  final EdgeInsets padding;

  /// The cursor to be displayed when hovering over the layer.
  final SystemMouseCursor layerHoverCursor;

  /// Internationalization support.
  final I18n i18n;

  /// Font size for text layers.
  final TextStyle emojiTextStyle;

  /// Font size for text layers.
  final double textFontSize;

  /// Enables high-performance scaling for free-style drawing when set to `true`.
  ///
  /// When this option is enabled, it optimizes scaling for improved performance.
  /// By default, it's set to `true` on mobile devices and `false` on desktop devices.
  final bool freeStyleHighPerformanceScaling;

  /// Enables or disables hit detection.
  /// When set to `true`, it allows detecting user interactions with the interface.
  final bool enabledHitDetection;

  /// Creates a [LayerWidget] with the specified properties.
  const LayerWidget({
    Key? key,
    required this.padding,
    required this.layerData,
    required this.onTapDown,
    required this.onTapUp,
    required this.onTap,
    required this.layerHoverCursor,
    required this.onRemoveTap,
    required this.i18n,
    required this.textFontSize,
    required this.emojiTextStyle,
    required this.enabledHitDetection,
    required this.freeStyleHighPerformanceScaling,
  }) : super(key: key);

  @override
  createState() => _LayerWidgetState();
}

class _LayerWidgetState extends State<LayerWidget> {
  /// The type of layer being represented.
  late _LayerType _layerType;

  /// Flag to control the display of a move cursor.
  bool _showMoveCursor = false;

  @override
  void initState() {
    if (widget.layerData is TextLayerData) {
      _layerType = _LayerType.text;
    } else if (widget.layerData is EmojiLayerData) {
      _layerType = _LayerType.emoji;
    } else if (widget.layerData is PaintingLayerData) {
      _layerType = _LayerType.canvas;
    } else {
      _layerType = _LayerType.unkown;
    }

    super.initState();
  }

  /// Handles a secondary tap up event, typically for showing a context menu.
  void _onSecondaryTapUp(TapUpDetails details) {
    if (_checkHitIsOutsideInCanvas()) return;
    final Offset clickPosition = details.globalPosition;

    // Show a popup menu at the click position
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        clickPosition.dx,
        clickPosition.dy,
        clickPosition.dx + 1.0, // Adding a small value to avoid zero width
        clickPosition.dy + 1.0, // Adding a small value to avoid zero height
      ),
      items: <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: 'remove',
          child: Row(
            children: [
              Icon(Icons.delete_outline),
              SizedBox(width: 4),
              Text('Remove'),
            ],
          ),
        ),
      ],
    ).then((String? selectedValue) {
      if (selectedValue != null) {
        widget.onRemoveTap();
      }
    });
  }

  /// Handles a tap event on the layer.
  void _onTap() {
    if (_checkHitIsOutsideInCanvas()) return;
    widget.onTap(_layer);
  }

  /// Handles a pointer down event on the layer.
  void _onPointerDown(PointerDownEvent event) {
    if (_checkHitIsOutsideInCanvas()) return;
    if (!isDesktop || event.buttons != kSecondaryMouseButton) {
      widget.onTapDown();
    }
  }

  /// Handles a pointer up event on the layer.
  void _onPointerUp(PointerUpEvent event) {
    widget.onTapUp();
  }

  /// Checks if the hit is outside the canvas for certain types of layers.
  bool _checkHitIsOutsideInCanvas() {
    return _layerType == _LayerType.canvas && !(_layer as PaintingLayerData).item.hit;
  }

  /// Calculates the transformation matrix for the layer's position and rotation.
  Matrix4 _calcTransformMatrix() {
    return Matrix4.identity()
      ..setEntry(3, 2, 0.001) // Add a small z-offset to avoid rendering issues
      ..rotateX(_layer.flipX ? pi : 0)
      ..rotateY(_layer.flipY ? pi : 0)
      ..rotateZ(_layer.rotation);
  }

  /// Returns the current layer being displayed.
  Layer get _layer => widget.layerData;

  /// Calculates the horizontal offset for the layer.
  double get offsetX => _layer.offset.dx + widget.padding.left;

  /// Calculates the vertical offset for the layer.
  double get offsetY => _layer.offset.dy + widget.padding.top;

  @override
  Widget build(BuildContext context) {
    // Position the widget with specified padding
    return Positioned(
      top: offsetY,
      left: offsetX,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: _buildPosition(), // Build the widget content
      ),
    );
  }

  /// Build the content with possible transformations
  Widget _buildPosition() {
    Matrix4 transformMatrix = _calcTransformMatrix();
    return Container(
      transform: transformMatrix,
      transformAlignment: Alignment.center,
      child: LayerDashedBorderHelper(
        layerData: widget.layerData,
        color: const Color(0xFF000000),
        child: MouseRegion(
          hitTestBehavior: HitTestBehavior.translucent,
          cursor: _showMoveCursor ? widget.layerHoverCursor : MouseCursor.defer,
          onEnter: (event) {
            if (_layerType != _LayerType.canvas) {
              setState(() {
                _showMoveCursor = true;
              });
            }
          },
          onExit: (event) {
            if (_layerType == _LayerType.canvas) {
              (widget.layerData as PaintingLayerData).item.hit = false;
            } else {
              setState(() {
                _showMoveCursor = false;
              });
            }
          },
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onSecondaryTapUp: isDesktop ? _onSecondaryTapUp : null,
            onTap: _onTap,
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: _onPointerDown,
              onPointerUp: _onPointerUp,
              child: _buildContent(),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the content widget based on the type of layer being displayed.
  Widget _buildContent() {
    switch (_layerType) {
      case _LayerType.emoji:
        return _buildEmoji();
      case _LayerType.text:
        return _buildText();
      case _LayerType.canvas:
        return _buildCanvas();
      default:
        return const SizedBox.shrink();
    }
  }

  /// Build the text widget
  Widget _buildText() {
    var layer = _layer as TextLayerData;
    double horizontalHelper = 10 * layer.scale;
    return Container(
      // Fix Hit-Box
      padding: EdgeInsets.only(
        left: horizontalHelper,
        right: horizontalHelper,
        bottom: 6.4 * layer.scale,
      ),
      child: RoundedBackgroundText(
        layer.text.toString(),
        backgroundColor: layer.background,
        textAlign: layer.align,
        style: TextStyle(
          fontSize: widget.textFontSize * _layer.scale,
          fontWeight: FontWeight.w400,
          color: layer.color,
          height: 1.55,
        ),
      ),
    );
  }

  /// Build the emoji widget
  Widget _buildEmoji() {
    var layer = _layer as EmojiLayerData;
    return Text(
      layer.emoji.toString(),
      textAlign: TextAlign.center,
      style: widget.emojiTextStyle.copyWith(
        fontSize: widget.textFontSize * _layer.scale,
      ),
    );
  }

  /// Build the canvas widget
  Widget _buildCanvas() {
    var layer = _layer as PaintingLayerData;
    return Padding(
      // Better hit detection for mobile devices
      padding: EdgeInsets.all(isDesktop ? 0 : 15),
      child: CustomPaint(
        size: layer.size,
        willChange: true,
        isComplex: layer.item.mode == PaintModeE.freeStyle,
        painter: DrawCanvas(
          item: layer.item,
          scale: widget.layerData.scale,
          enabledHitDetection: widget.enabledHitDetection,
          freeStyleHighPerformanceScaling: widget.freeStyleHighPerformanceScaling,
        ),
      ),
    );
  }
}

// ignore: camel_case_types
enum _LayerType { emoji, text, canvas, unkown }

/// Enumeration for controlling the background color mode of the text layer.
enum LayerBackgroundColorModeE {
  background,
  backgroundAndColor,
  backgroundAndColorWithOpacity,
  onlyColor,
}