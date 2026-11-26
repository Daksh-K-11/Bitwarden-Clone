import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/common_widgets.dart';
import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../domain/generators.dart';

enum GeneratorKind { password, passphrase, username }

class GeneratorState {
  const GeneratorState({
    this.kind = GeneratorKind.password,
    this.password = const PasswordOptions(),
    this.passphrase = const PassphraseOptions(),
    this.username = const UsernameOptions(),
    this.value = '',
    this.history = const [],
  });
  final GeneratorKind kind;
  final PasswordOptions password;
  final PassphraseOptions passphrase;
  final UsernameOptions username;
  final String value;

  /// Session-only history (memory, cleared on lock/restart).
  final List<String> history;

  GeneratorState copyWith({
    GeneratorKind? kind,
    PasswordOptions? password,
    PassphraseOptions? passphrase,
    UsernameOptions? username,
    String? value,
    List<String>? history,
  }) => GeneratorState(
    kind: kind ?? this.kind,
    password: password ?? this.password,
    passphrase: passphrase ?? this.passphrase,
    username: username ?? this.username,
    value: value ?? this.value,
    history: history ?? this.history,
  );
}

final generatorProvider = NotifierProvider<GeneratorController, GeneratorState>(GeneratorController.new);

class GeneratorController extends Notifier<GeneratorState> {
  String? error;

  @override
  GeneratorState build() {
    Future.microtask(regenerate);
    return const GeneratorState();
  }

  void regenerate() {
    final rng = ref.read(secureRandomProvider);
    final words = ref.read(wordListProvider);
    try {
      final v = switch (state.kind) {
        GeneratorKind.password => PasswordGenerator(rng).generate(state.password),
        GeneratorKind.passphrase => PassphraseGenerator(rng, words).generate(state.passphrase),
        GeneratorKind.username => UsernameGenerator(rng, words).generate(state.username),
      };
      error = null;
      state = state.copyWith(value: v, history: [v, ...state.history].take(10).toList());
    } on GeneratorException catch (e) {
      error = e.message;
      state = state.copyWith(value: '');
    }
  }

  void update(GeneratorState Function(GeneratorState) fn) {
    state = fn(state);
    regenerate();
  }

  double entropy() => switch (state.kind) {
    GeneratorKind.password => PasswordGenerator.entropyBits(state.password),
    GeneratorKind.passphrase => PassphraseGenerator(
      ref.read(secureRandomProvider),
      ref.read(wordListProvider),
    ).entropyBits(state.passphrase),
    GeneratorKind.username => 0,
  };
}

/// Bottom sheet used from item forms; returns the chosen value.
Future<String?> showGeneratorSheet(BuildContext context, {GeneratorKind kind = GeneratorKind.password}) =>
    showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (c) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (c, scroll) => GeneratorBody(scrollController: scroll, onUse: (v) => Navigator.pop(c, v)),
      ),
    );

class GeneratorScreen extends StatelessWidget {
  const GeneratorScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Generator')),
    body: const GeneratorBody(),
  );
}

class GeneratorBody extends ConsumerWidget {
  const GeneratorBody({super.key, this.onUse, this.scrollController});
  final void Function(String)? onUse;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(generatorProvider);
    final ctrl = ref.read(generatorProvider.notifier);
    final s = Theme.of(context).colorScheme;
    final bits = ctrl.entropy();

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(AppTheme.space4),
      children: [
        SegmentedButton<GeneratorKind>(
          segments: const [
            ButtonSegment(value: GeneratorKind.password, label: Text('Password')),
            ButtonSegment(value: GeneratorKind.passphrase, label: Text('Passphrase')),
            ButtonSegment(value: GeneratorKind.username, label: Text('Username')),
          ],
          selected: {st.kind},
          showSelectedIcon: false,
          onSelectionChanged: (k) => ctrl.update((x) => x.copyWith(kind: k.first)),
        ),
        const SizedBox(height: AppTheme.space4),
        Card(
          color: s.primaryContainer.withValues(alpha: 0.35),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (ctrl.error != null) Text(ctrl.error!, style: TextStyle(color: s.error)) else SecretText(st.value),
                if (st.kind != GeneratorKind.username) ...[
                  const SizedBox(height: AppTheme.space2),
                  StrengthMeter(password: st.value, showFeedback: false),
                  Text('Random entropy ≈ ${bits.round()} bits', style: Theme.of(context).textTheme.bodySmall),
                ],
                const SizedBox(height: AppTheme.space3),
                Row(
                  children: [
                    IconButton.filledTonal(
                      tooltip: 'Regenerate',
                      icon: const Icon(Icons.refresh_rounded),
                      onPressed: ctrl.regenerate,
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'Copy',
                      icon: const Icon(Icons.copy_rounded),
                      onPressed: () => copySecret(
                        context,
                        ref,
                        st.value,
                        st.kind == GeneratorKind.username ? 'Username' : 'Password',
                        sensitive: st.kind != GeneratorKind.username,
                      ),
                    ),
                    const Spacer(),
                    if (onUse == null)
                      TextButton.icon(
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save as login'),
                        onPressed: st.value.isEmpty
                            ? null
                            : () => context.push(
                                '/item/new?type=login',
                                // Secrets travel in `extra`, never in the URL.
                                extra: {st.kind == GeneratorKind.username ? 'username' : 'password': st.value},
                              ),
                      ),
                    if (onUse != null)
                      FilledButton(
                        style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
                        onPressed: st.value.isEmpty ? null : () => onUse!(st.value),
                        child: const Text('Use'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppTheme.space3),
        ...switch (st.kind) {
          GeneratorKind.password => _passwordOptions(
            context,
            st.password,
            (o) => ctrl.update((x) => x.copyWith(password: o)),
          ),
          GeneratorKind.passphrase => _passphraseOptions(
            st.passphrase,
            (o) => ctrl.update((x) => x.copyWith(passphrase: o)),
          ),
          GeneratorKind.username => _usernameOptions(st.username, (o) => ctrl.update((x) => x.copyWith(username: o))),
        },
        if (st.history.length > 1 && onUse == null) ...[
          const SectionHeader('This session'),
          Text('Kept in memory only and cleared when the app closes.', style: Theme.of(context).textTheme.bodySmall),
          for (final h in st.history.skip(1))
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                h,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18),
                onPressed: () => copySecret(context, ref, h, 'Value'),
              ),
            ),
        ],
      ],
    );
  }

  List<Widget> _passwordOptions(BuildContext context, PasswordOptions o, void Function(PasswordOptions) set) => [
    Row(
      children: [
        const Text('Length'),
        Expanded(
          child: Slider(
            min: 8,
            max: 128,
            divisions: 120,
            value: o.length.toDouble().clamp(8, 128),
            label: '${o.length}',
            onChanged: (v) => set(o.copyWith(length: v.round())),
          ),
        ),
        SizedBox(width: 36, child: Text('${o.length}', textAlign: TextAlign.end)),
      ],
    ),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Uppercase (A-Z)'),
      value: o.uppercase,
      onChanged: (v) => set(o.copyWith(uppercase: v)),
    ),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Lowercase (a-z)'),
      value: o.lowercase,
      onChanged: (v) => set(o.copyWith(lowercase: v)),
    ),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Numbers (0-9)'),
      value: o.digits,
      onChanged: (v) => set(o.copyWith(digits: v)),
    ),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text(r'Symbols (!@#$%...)'),
      value: o.symbols,
      onChanged: (v) => set(o.copyWith(symbols: v)),
    ),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Exclude ambiguous symbols'),
      subtitle: const Text(
        r'{ } [ ] ( ) / \ '
        "' \" ` ~ , ; : . < >",
      ),
      value: o.excludeAmbiguous,
      onChanged: (v) => set(o.copyWith(excludeAmbiguous: v)),
    ),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Avoid similar characters'),
      subtitle: const Text('i l 1 L o 0 O I'),
      value: o.avoidSimilar,
      onChanged: (v) => set(o.copyWith(avoidSimilar: v)),
    ),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('No repeated characters'),
      value: o.avoidRepeating,
      onChanged: (v) => set(o.copyWith(avoidRepeating: v)),
    ),
    TextFormField(
      initialValue: o.customCharset,
      autocorrect: false,
      enableSuggestions: false,
      decoration: const InputDecoration(
        labelText: 'Custom character set (optional)',
        helperText: 'Overrides the options above when set',
      ),
      onChanged: (v) => set(o.copyWith(customCharset: v)),
    ),
  ];

  List<Widget> _passphraseOptions(PassphraseOptions o, void Function(PassphraseOptions) set) => [
    Row(
      children: [
        const Text('Words'),
        Expanded(
          child: Slider(
            min: 3,
            max: 12,
            divisions: 9,
            value: o.words.toDouble(),
            label: '${o.words}',
            onChanged: (v) => set(o.copyWith(words: v.round())),
          ),
        ),
        SizedBox(width: 28, child: Text('${o.words}', textAlign: TextAlign.end)),
      ],
    ),
    TextFormField(
      initialValue: o.separator,
      maxLength: 3,
      decoration: const InputDecoration(labelText: 'Separator'),
      onChanged: (v) => set(o.copyWith(separator: v)),
    ),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Capitalize'),
      value: o.capitalize,
      onChanged: (v) => set(o.copyWith(capitalize: v)),
    ),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Include a number'),
      value: o.includeNumber,
      onChanged: (v) => set(o.copyWith(includeNumber: v)),
    ),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Include a symbol'),
      value: o.includeSymbol,
      onChanged: (v) => set(o.copyWith(includeSymbol: v)),
    ),
    const Text('Words from the EFF large wordlist (7,776 words, ~12.9 bits each).'),
  ];

  List<Widget> _usernameOptions(UsernameOptions o, void Function(UsernameOptions) set) => [
    SegmentedButton<UsernameStyle>(
      segments: const [
        ButtonSegment(value: UsernameStyle.adjectiveNoun, label: Text('Adj + noun')),
        ButtonSegment(value: UsernameStyle.randomWord, label: Text('Word')),
        ButtonSegment(value: UsernameStyle.randomCharacters, label: Text('Random')),
      ],
      selected: {o.style},
      onSelectionChanged: (v) => set(o.copyWith(style: v.first)),
    ),
    const SizedBox(height: AppTheme.space3),
    if (o.style != UsernameStyle.randomCharacters) ...[
      TextFormField(
        initialValue: o.separator,
        maxLength: 2,
        decoration: const InputDecoration(labelText: 'Separator'),
        onChanged: (v) => set(o.copyWith(separator: v)),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Capitalize'),
        value: o.capitalize,
        onChanged: (v) => set(o.copyWith(capitalize: v)),
      ),
      Row(
        children: [
          const Text('Digits'),
          Expanded(
            child: Slider(
              min: 0,
              max: 6,
              divisions: 6,
              value: o.appendDigits.toDouble(),
              label: '${o.appendDigits}',
              onChanged: (v) => set(o.copyWith(appendDigits: v.round())),
            ),
          ),
          Text('${o.appendDigits}'),
        ],
      ),
    ] else
      Row(
        children: [
          const Text('Length'),
          Expanded(
            child: Slider(
              min: 4,
              max: 32,
              divisions: 28,
              value: o.length.toDouble(),
              label: '${o.length}',
              onChanged: (v) => set(o.copyWith(length: v.round())),
            ),
          ),
          Text('${o.length}'),
        ],
      ),
  ];
}
