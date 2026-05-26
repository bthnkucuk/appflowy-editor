import 'package:appflowy_editor/appflowy_editor.dart';
import 'heading_block_component/heading_command_shortcut.dart';
import '../util/platform_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const standardBlockComponentConfiguration = BlockComponentConfiguration();

final Map<String, BlockComponentBuilder> standardBlockComponentBuilderMap = {
  PageBlockKeys.type: PageBlockComponentBuilder(),
  ParagraphBlockKeys.type: ParagraphBlockComponentBuilder(
    configuration: standardBlockComponentConfiguration.copyWith(
      placeholderText: (_) => PlatformExtension.isDesktopOrWeb
          ? aft.slashPlaceHolder
          : ' ',
    ),
  ),
  TodoListBlockKeys.type: TodoListBlockComponentBuilder(
    configuration: standardBlockComponentConfiguration.copyWith(
      placeholderText: (_) => aft.toDoPlaceholder,
    ),
    toggleChildrenTriggers: [
      LogicalKeyboardKey.shift,
      LogicalKeyboardKey.shiftLeft,
      LogicalKeyboardKey.shiftRight,
    ],
  ),
  BulletedListBlockKeys.type: BulletedListBlockComponentBuilder(
    configuration: standardBlockComponentConfiguration.copyWith(
      placeholderText: (_) => aft.listItemPlaceholder,
    ),
  ),
  NumberedListBlockKeys.type: NumberedListBlockComponentBuilder(
    configuration: standardBlockComponentConfiguration.copyWith(
      placeholderText: (_) => aft.listItemPlaceholder,
    ),
  ),
  QuoteBlockKeys.type: QuoteBlockComponentBuilder(
    configuration: standardBlockComponentConfiguration.copyWith(
      placeholderText: (_) => aft.quote,
    ),
  ),
  HeadingBlockKeys.type: HeadingBlockComponentBuilder(
    configuration: standardBlockComponentConfiguration.copyWith(
      placeholderText: (node) =>
          'Heading ${node.attributes[HeadingBlockKeys.level]}',
    ),
  ),
  ImageBlockKeys.type: ImageBlockComponentBuilder(),
  DividerBlockKeys.type: DividerBlockComponentBuilder(
    configuration: standardBlockComponentConfiguration.copyWith(
      padding: (node) => const EdgeInsets.symmetric(vertical: 8.0),
    ),
  ),
  TableBlockKeys.type: TableBlockComponentBuilder(),
  TableCellBlockKeys.type: TableCellBlockComponentBuilder(),
};

final List<CharacterShortcutEvent> standardCharacterShortcutEvents = [
  // '\n'
  insertNewLineAfterBulletedList,
  insertNewLineAfterTodoList,
  insertNewLineAfterNumberedList,
  insertNewLineAfterHeading,
  insertNewLine,

  // bulleted list
  formatAsteriskToBulletedList,
  formatMinusToBulletedList,

  // numbered list
  formatNumberToNumberedList,

  // quote
  formatDoubleQuoteToQuote,

  // heading
  formatSignToHeading,

  // checkbox
  // format unchecked box, [] or -[]
  formatEmptyBracketsToUncheckedBox,
  formatHyphenEmptyBracketsToUncheckedBox,

  // format checked box, [x] or -[x]
  formatFilledBracketsToCheckedBox,
  formatHyphenFilledBracketsToCheckedBox,

  // slash
  slashCommand,

  // divider
  convertMinusesToDivider,
  convertStarsToDivider,
  convertUnderscoreToDivider,

  // markdown syntax
  ...markdownSyntaxShortcutEvents,

  // convert => to arrow
  formatGreaterEqual,
];

final List<CommandShortcutEvent> standardCommandShortcutEvents = [
  // undo, redo
  undoCommand,
  redoCommand,

  // backspace
  convertToParagraphCommand,
  ...tableCommands,
  backspaceCommand,
  deleteLeftWordCommand,
  deleteLeftSentenceCommand,

  //delete
  deleteCommand,
  deleteRightWordCommand,

  // arrow keys
  ...arrowLeftKeys,
  ...arrowRightKeys,
  ...arrowUpKeys,
  ...arrowDownKeys,

  //
  homeCommand,
  endCommand,

  //
  toggleTodoListCommand,
  ...toggleMarkdownCommands,
  ...toggleHeadingCommands,
  toggleHighlightCommand,
  showLinkMenuCommand,
  openInlineLinkCommand,
  openLinksCommand,

  //
  indentCommand,
  outdentCommand,

  //
  exitEditingCommand,

  //
  pageUpCommand,
  pageDownCommand,

  //
  selectAllCommand,

  // copy paste and cut
  copyCommand,
  ...pasteCommands,
  cutCommand,
];
