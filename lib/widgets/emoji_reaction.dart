import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../api/model/model.dart';
import '../api/route/messages.dart';
import '../model/content.dart';
import 'content.dart';
import 'store.dart';
import 'text.dart';

class ReactionChipsList extends StatelessWidget {
  const ReactionChipsList({
    super.key,
    required this.messageId,
    required this.reactions,
  });

  final int messageId;
  final Reactions reactions;

  @override
  Widget build(BuildContext context) {
    final store = PerAccountStoreWidget.of(context);
    final displayEmojiReactionUsers = store.userSettings?.displayEmojiReactionUsers ?? false;
    final showNames = displayEmojiReactionUsers && reactions.total <= 3;

    return Wrap(spacing: 4, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center,
      children: reactions.aggregated.map((reactionVotes) => ReactionChip(
        showName: showNames,
        messageId: messageId, reactionWithVotes: reactionVotes),
      ).toList());
  }
}

final _textColorSelected = const HSLColor.fromAHSL(1, 210, 0.20, 0.20).toColor();
final _textColorUnselected = const HSLColor.fromAHSL(1, 210, 0.20, 0.25).toColor();

const _backgroundColorSelected = Colors.white;
// TODO shadow effect, following web, which uses `box-shadow: inset`:
//   https://developer.mozilla.org/en-US/docs/Web/CSS/box-shadow#inset
//   Needs Flutter support for something like that:
//     https://github.com/flutter/flutter/issues/18636
//     https://github.com/flutter/flutter/issues/52999
//   Until then use a solid color; a much-lightened version of the shadow color.
//   Also adapt by making [_borderColorUnselected] more transparent, so we'll
//   want to check that against web when implementing the shadow.
final _backgroundColorUnselected = const HSLColor.fromAHSL(0.15, 210, 0.50, 0.875).toColor();

final _borderColorSelected = Colors.black.withOpacity(0.40);
// TODO see TODO on [_backgroundColorUnselected] about shadow effect
final _borderColorUnselected = Colors.black.withOpacity(0.06);

class ReactionChip extends StatelessWidget {
  final bool showName;
  final int messageId;
  final ReactionWithVotes reactionWithVotes;

  const ReactionChip({
    super.key,
    required this.showName,
    required this.messageId,
    required this.reactionWithVotes,
  });

  @override
  Widget build(BuildContext context) {
    final store = PerAccountStoreWidget.of(context);

    final reactionType = reactionWithVotes.reactionType;
    final emojiCode = reactionWithVotes.emojiCode;
    final emojiName = reactionWithVotes.emojiName;
    final userIds = reactionWithVotes.userIds;

    final emojiset = store.userSettings?.emojiset ?? Emojiset.google;

    final selfUserId = store.account.userId;
    final selfVoted = userIds.contains(selfUserId);
    final label = showName
      // TODO(i18n): List formatting, like you can do in JavaScript:
      //   new Intl.ListFormat('ja').format(['Chris', 'Greg', 'Alya', 'Shu'])
      //   // 'Chris、Greg、Alya、Shu'
      ? userIds.map((id) {
          return id == selfUserId
            ? 'You'
            : store.users[id]?.fullName ?? '(unknown user)'; // TODO(i18n)
        }).join(', ')
      : userIds.length.toString();

    final borderColor =     selfVoted ? _borderColorSelected       : _borderColorUnselected;
    final labelColor =      selfVoted ? _textColorSelected         : _textColorUnselected;
    final backgroundColor = selfVoted ? _backgroundColorSelected   : _backgroundColorUnselected;
    final splashColor =     selfVoted ? _backgroundColorUnselected : _backgroundColorSelected;
    final highlightColor =  splashColor.withOpacity(0.5);

    final borderSide = BorderSide(color: borderColor, width: 1);
    final shape = StadiumBorder(side: borderSide);

    final Widget emoji;
    if (emojiset == Emojiset.text) {
      emoji = _TextEmoji(emojiName: emojiName, selected: selfVoted);
    } else {
      switch (reactionType) {
        case ReactionType.unicodeEmoji:
          emoji = _UnicodeEmoji(
            emojiCode: emojiCode,
            emojiName: emojiName,
            selected: selfVoted,
          );
        case ReactionType.realmEmoji:
        case ReactionType.zulipExtraEmoji:
          emoji = _ImageEmoji(
            emojiCode: emojiCode,
            emojiName: emojiName,
            selected: selfVoted,
          );
      }
    }

    return Tooltip(
      // TODO(#434): Semantics with eg "Reaction: <emoji name>; you and N others: <names>"
      excludeFromSemantics: true,
      message: emojiName,
      child: Material(
        color: backgroundColor,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          splashColor: splashColor,
          highlightColor: highlightColor,
          onTap: () {
            (selfVoted ? removeReaction : addReaction).call(store.connection,
              messageId: messageId,
              reactionType: reactionType,
              emojiCode: emojiCode,
              emojiName: emojiName,
            );
          },
          child: Padding(
            // 1px of this padding accounts for the border, which Flutter
            // just paints without changing size.
            padding: const EdgeInsetsDirectional.fromSTEB(4, 2, 5, 2),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxRowWidth = constraints.maxWidth;
                // To give text emojis some room so they need fewer line breaks
                // when the label is long.
                // TODO(#433) This is a bit overzealous. The shorter width
                //   won't be necessary when the text emoji is very short, or
                //   in the near-universal case of small, square emoji (i.e.
                //   Unicode and image emoji). But it's not simple to recognize
                //   those cases here: we don't know at this point whether we'll
                //   be showing a text emoji, because we use that for various
                //   error conditions (including when an image fails to load,
                //   which we learn about especially late).
                final maxLabelWidth = (maxRowWidth - 6) * 0.75; // 6 is padding

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // So text-emoji chips are at least as tall as square-emoji
                    // ones (probably a good thing).
                    SizedBox(height: _squareEmojiScalerClamped(context).scale(_squareEmojiSize)),
                    Flexible( // [Flexible] to let text emojis expand if they can
                      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                        child: emoji)),
                    // Added vertical: 1 to give some space when the label is
                    // taller than the emoji (e.g. because it needs multiple lines)
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                      child: Container(
                        constraints: BoxConstraints(maxWidth: maxLabelWidth),
                        child: Text(
                          textWidthBasis: TextWidthBasis.longestLine,
                          textScaler: _labelTextScalerClamped(context),
                          style: TextStyle(
                            fontFamily: 'Source Sans 3',
                            fontSize: (14 * 0.90),
                            height: 13 / (14 * 0.90),
                            color: labelColor,
                          ).merge(selfVoted
                            ? weightVariableTextStyle(context, wght: 600, wghtIfPlatformRequestsBold: 900)
                            : weightVariableTextStyle(context)),
                          label),
                      )),
                  ]);
                })))));
  }
}

/// The size of a square emoji (Unicode or image).
///
/// Should be scaled by [_emojiTextScalerClamped].
const _squareEmojiSize = 17.0;

/// A font size that, with Noto Color Emoji and our line-height config,
/// causes a Unicode emoji to occupy a [_squareEmojiSize] square in the layout.
///
/// Determined experimentally:
///   <https://github.com/zulip/zulip-flutter/pull/410#discussion_r1402808701>
const _notoColorEmojiTextSize = 14.5;

/// A [TextScaler] that limits Unicode and image emojis' max scale factor,
/// to leave space for the label.
///
/// This should scale [_squareEmojiSize] for Unicode and image emojis.
// TODO(a11y) clamp higher?
TextScaler _squareEmojiScalerClamped(BuildContext context) =>
  MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 2);

/// A [TextScaler] that limits text emojis' max scale factor,
/// to minimize the need for line breaks.
// TODO(a11y) clamp higher?
TextScaler _textEmojiScalerClamped(BuildContext context) =>
  MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.5);

/// A [TextScaler] that limits the label's max scale factor,
/// to minimize the need for line breaks.
// TODO(a11y) clamp higher?
TextScaler _labelTextScalerClamped(BuildContext context) =>
  MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 2);

class _UnicodeEmoji extends StatelessWidget {
  const _UnicodeEmoji({
    required this.emojiCode,
    required this.emojiName,
    required this.selected,
  });

  final String emojiCode;
  final String emojiName;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final parsed = tryParseEmojiCodeToUnicode(emojiCode);
    if (parsed == null) { // TODO(log)
      return _TextEmoji(emojiName: emojiName, selected: selected);
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return Text(
          textScaler: _squareEmojiScalerClamped(context),
          style: const TextStyle(
            fontFamily: 'Noto Color Emoji',
            fontSize: _notoColorEmojiTextSize,
          ),
          strutStyle: const StrutStyle(fontSize: _notoColorEmojiTextSize, forceStrutHeight: true),
          parsed);
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        // We expect the font "Apple Color Emoji" to be used. There are some
        // surprises in how Flutter ends up rendering emojis in this font:
        // - With a font size of 17px, the emoji visually seems to be about 17px
        //   square. (Unlike on Android, with Noto Color Emoji, where a 14.5px font
        //   size gives an emoji that looks 17px square.) See:
        //     <https://github.com/flutter/flutter/issues/28894>
        // - The emoji doesn't fill the space taken by the [Text] in the layout.
        //   There's whitespace above, below, and on the right. See:
        //     <https://github.com/flutter/flutter/issues/119623>
        //
        // That extra space would be problematic, except we've used a [Stack] to
        // make the [Text] "positioned" so the space doesn't add margins around the
        // visible part. Key points that enable the [Stack] workaround:
        // - The emoji seems approximately vertically centered (this is
        //   accomplished with help from a [StrutStyle]; see below).
        // - There seems to be approximately no space on its left.
        final boxSize = _squareEmojiScalerClamped(context).scale(_squareEmojiSize);
        return Stack(alignment: Alignment.centerLeft, clipBehavior: Clip.none, children: [
          SizedBox(height: boxSize, width: boxSize),
          PositionedDirectional(start: 0, child: Text(
            textScaler: _squareEmojiScalerClamped(context),
            style: const TextStyle(fontSize: _squareEmojiSize),
            strutStyle: const StrutStyle(fontSize: _squareEmojiSize, forceStrutHeight: true),
            parsed)),
        ]);
    }
  }
}

class _ImageEmoji extends StatelessWidget {
  const _ImageEmoji({
    required this.emojiCode,
    required this.emojiName,
    required this.selected,
  });

  final String emojiCode;
  final String emojiName;
  final bool selected;

  Widget get _textFallback => _TextEmoji(emojiName: emojiName, selected: selected);

  @override
  Widget build(BuildContext context) {
    final store = PerAccountStoreWidget.of(context);

    // Some people really dislike animated emoji.
    final doNotAnimate =
      // From reading code, this doesn't actually get set on iOS:
      //   https://github.com/zulip/zulip-flutter/pull/410#discussion_r1408522293
      MediaQuery.disableAnimationsOf(context)
      || (defaultTargetPlatform == TargetPlatform.iOS
        // TODO(upstream) On iOS 17+ (new in 2023), there's a more closely
        //   relevant setting than "reduce motion". It's called "auto-play
        //   animated images", and we should file an issue to expose it.
        //   See GitHub comment linked above.
        && WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.reduceMotion);

    final String src;
    switch (emojiCode) {
      case 'zulip': // the single "zulip extra emoji"
        src = '/static/generated/emoji/images/emoji/unicode/zulip.png';
      default:
        final item = store.realmEmoji[emojiCode];
        if (item == null) {
          return _textFallback;
        }
        src = doNotAnimate && item.stillUrl != null ? item.stillUrl! : item.sourceUrl;
    }
    final parsedSrc = Uri.tryParse(src);
    if (parsedSrc == null) { // TODO(log)
      return _textFallback;
    }
    final resolved = store.account.realmUrl.resolveUri(parsedSrc);

    // Unicode and text emoji get scaled; it would look weird if image emoji didn't.
    final size = _squareEmojiScalerClamped(context).scale(_squareEmojiSize);

    return RealmContentNetworkImage(
      resolved,
      width: size,
      height: size,
      errorBuilder: (context, _, __) => _textFallback,
    );
  }
}

class _TextEmoji extends StatelessWidget {
  const _TextEmoji({required this.emojiName, required this.selected});

  final String emojiName;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Text(
      textAlign: TextAlign.end,
      textScaler: _textEmojiScalerClamped(context),
      style: TextStyle(
        fontFamily: 'Source Sans 3',
        fontSize: 14 * 0.8,
        height: 1, // to be denser when we have to wrap
        color: selected ? _textColorSelected : _textColorUnselected,
      ).merge(selected
        ? weightVariableTextStyle(context, wght: 600, wghtIfPlatformRequestsBold: 900)
        : weightVariableTextStyle(context)),
      // Encourage line breaks before "_" (common in these), but try not
      // to leave a colon alone on a line. See:
      //   <https://github.com/flutter/flutter/issues/61081#issuecomment-1103330522>
      ':\ufeff${emojiName.replaceAll('_', '\u200b_')}\ufeff:');
  }
}
