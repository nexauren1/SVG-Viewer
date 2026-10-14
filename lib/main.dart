import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';

void main() => runApp(const SvgViewerApp());
const _storage = MethodChannel('svg_viewer/storage');

class SvgViewerApp extends StatelessWidget {
  const SvgViewerApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'SVG Viewer',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4)),
      scaffoldBackgroundColor: const Color(0xFFF8F7FC),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    ),
    darkTheme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6750A4),
        brightness: Brightness.dark,
      ),
    ),
    home: const SvgHomePage(),
  );
}

class SvgFileEntry {
  const SvgFileEntry({required this.name, required this.uri});
  final String name;
  final String uri;
  factory SvgFileEntry.fromMap(Map<dynamic, dynamic> map) =>
      SvgFileEntry(name: map['name']?.toString() ?? 'untitled.svg',
                   uri: map['uri']?.toString() ?? '');
}

class SvgHomePage extends StatefulWidget {
  const SvgHomePage({super.key});
  @override
  State<SvgHomePage> createState() => _SvgHomePageState();
}

class _SvgHomePageState extends State<SvgHomePage> {
  List<SvgFileEntry> _files = [];
  bool _busy = false;
  String? _error;
  bool _folderChosen = false;

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _pickSvg() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: const ['svg'], withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final source = file.bytes != null
          ? utf8.decode(file.bytes!, allowMalformed: false)
          : file.path != null ? await File(file.path!).readAsString() : null;
      if (source == null) throw const FormatException('O conteúdo do ficheiro não está acessível.');
      if (!mounted) return;
      await _preview(file.name, source);
    } catch (_) {
      _message('Não foi possível abrir o SVG. Verifica se o ficheiro é válido.');
    }
  }

  Future<void> _scan({bool choose = true}) async {
    setState(() { _busy = true; _error = null; });
    try {
      final list = await _storage.invokeListMethod<dynamic>(
        choose ? 'selectFolderAndScan' : 'rescan',
      );
      final found = (list ?? []).whereType<Map>().map(SvgFileEntry.fromMap).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (!mounted) return;
      setState(() { _files = found; _folderChosen = true; _busy = false; });
      _message(found.isEmpty ? 'Não foram encontrados SVG nesta pasta.'
          : found.length.toString() + ' ficheiro(s) SVG encontrado(s).');
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() { _busy = false; _error = e.message ?? 'Não foi possível pesquisar a pasta.'; });
      _message(_error!);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'A pesquisa de pastas está disponível na aplicação Android.';
      });
      _message(_error!);
    }
  }

  Future<void> _openFound(SvgFileEntry file) async {
    setState(() => _busy = true);
    try {
      final source = await _storage.invokeMethod<String>('readDocument', {'uri': file.uri});
      if (source != null && mounted) await _preview(file.name, source);
    } on PlatformException catch (e) {
      _message(e.message ?? 'Não foi possível abrir este SVG.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _preview(String name, String source) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => SvgPreviewPage(filename: name, source: source)),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('SVG Viewer'),
      actions: [
        IconButton(
          tooltip: 'Pesquisar novamente',
          onPressed: _busy || !_folderChosen ? null : () => _scan(choose: false),
          icon: const Icon(Icons.refresh_rounded),
        ),
        const SizedBox(width: 8),
      ],
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4E3A89), Color(0xFF8870D4)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 54, height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(Icons.polyline_rounded, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 20),
              const Text('Os teus vetores,\nsempre nítidos.',
                style: TextStyle(color: Colors.white, fontSize: 28,
                  height: 1.1, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Text('Abre, inspeciona e edita SVG diretamente no telefone.',
                style: TextStyle(color: Colors.white.withValues(alpha: .9), height: 1.4)),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _busy ? null : _pickSvg,
                icon: const Icon(Icons.file_open_rounded),
                label: const Text('Abrir um SVG'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white, foregroundColor: const Color(0xFF4E3A89),
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          Card(child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.folder_open_rounded), SizedBox(width: 10),
                Expanded(child: Text('Encontrar SVG no dispositivo',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
              ]),
              const SizedBox(height: 8),
              Text('Escolhe uma pasta. A aplicação procura SVG nessa pasta e nas subpastas. O acesso é limitado à pasta que autorizares.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.45)),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _scan(),
                icon: const Icon(Icons.manage_search_rounded),
                label: const Text('Autorizar pasta e pesquisar'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
              ),
            ]),
          )),
          const SizedBox(height: 24),
          Row(children: [
            const Expanded(child: Text('Ficheiros encontrados',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
            if (_files.isNotEmpty) Text(_files.length.toString(),
              style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          ]),
          const SizedBox(height: 8),
          if (_busy)
            const Padding(padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()))
          else if (_files.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(children: [
                const Icon(Icons.folder_off_outlined, size: 34),
                const SizedBox(height: 10),
                Text(_error ?? 'Ainda não há SVG na lista',
                  textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 5),
                Text(_folderChosen ? 'Escolhe outra pasta ou abre um SVG diretamente.'
                    : 'Abre um ficheiro ou autoriza uma pasta para começar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ]),
            )
          else
            ..._files.map((file) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.image_outlined)),
                title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: const Text('Ficheiro SVG'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _openFound(file),
              ),
            )),
          const SizedBox(height: 16),
          const Text('Offline • Sem conta • Os teus ficheiros ficam no dispositivo',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    ),
  );
}

class SvgPreviewPage extends StatefulWidget {
  const SvgPreviewPage({super.key, required this.filename, required this.source});
  final String filename;
  final String source;
  @override
  State<SvgPreviewPage> createState() => _SvgPreviewPageState();
}

class _SvgPreviewPageState extends State<SvgPreviewPage> {
  Color _background = const Color(0xFFF1F0F6);

  Future<void> _edit() async {
    final updated = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => SvgEditorPage(filename: widget.filename, source: widget.source),
      ),
    );
    if (updated != null && mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
        builder: (_) => SvgPreviewPage(filename: widget.filename, source: updated),
      ));
    }
  }

  Future<void> _share() async {
    await SharePlus.instance.share(
      ShareParams(text: widget.source, subject: widget.filename),
    );
  }

  @override
  Widget build(BuildContext context) {
    final swatches = [
      const Color(0xFFF1F0F6), Colors.white,
      const Color(0xFF24232A), const Color(0xFFDDEBDF),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.filename, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(tooltip: 'Editar SVG', onPressed: _edit, icon: const Icon(Icons.edit_note_rounded)),
          IconButton(tooltip: 'Partilhar código SVG', onPressed: _share, icon: const Icon(Icons.share_rounded)),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: BoxDecoration(
              color: _background,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            clipBehavior: Clip.antiAlias,
            child: InteractiveViewer(
              minScale: .25, maxScale: 12, boundaryMargin: const EdgeInsets.all(100),
              child: Center(child: Padding(
                padding: const EdgeInsets.all(20),
                child: SvgPicture.string(widget.source, fit: BoxFit.contain),
              )),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Fundo da pré-visualização', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Row(children: swatches.map((color) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: InkWell(
                onTap: () => setState(() => _background = color),
                borderRadius: BorderRadius.circular(24),
                child: Container(width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: color, shape: BoxShape.circle,
                    border: Border.all(
                      color: _background == color ? Theme.of(context).colorScheme.primary : Colors.grey,
                      width: _background == color ? 3 : 1,
                    ),
                  )),
              ),
            )).toList()),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _edit, icon: const Icon(Icons.edit_rounded),
              label: const Text('Editar código SVG'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
          ]),
        ),
      ]),
    );
  }
}

class SvgEditorPage extends StatefulWidget {
  const SvgEditorPage({super.key, required this.filename, required this.source});
  final String filename;
  final String source;
  @override
  State<SvgEditorPage> createState() => _SvgEditorPageState();
}

class _SvgEditorPageState extends State<SvgEditorPage> {
  late final TextEditingController _controller;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.source);
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  Future<void> _saveCopy() async {
    final source = _controller.text;
    final trimmed = source.trimLeft();
    if (!trimmed.startsWith('<svg') && !trimmed.startsWith('<?xml')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('O conteúdo não parece ser SVG/XML válido.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      var base = widget.filename;
      if (base.toLowerCase().endsWith('.svg')) base = base.substring(0, base.length - 4);
      final saved = await _storage.invokeMethod<bool>('saveSvgCopy', {
        'name': base + '_edited.svg', 'content': source,
      });
      if (!mounted) return;
      if (saved == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cópia guardada. O original foi preservado.')),
        );
        Navigator.of(context).pop(source);
      }
    } on PlatformException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Não foi possível guardar a cópia.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _share() async {
    await SharePlus.instance.share(
      ShareParams(text: _controller.text, subject: widget.filename),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Editar SVG'), actions: [
      IconButton(tooltip: 'Partilhar código', onPressed: _share, icon: const Icon(Icons.share_rounded)),
      const SizedBox(width: 8),
    ]),
    body: Column(children: [
      Container(
        width: double.infinity, padding: const EdgeInsets.all(12),
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: Text('A editar: ' + widget.filename + '. Guarda como cópia para proteger o original.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ),
      Expanded(child: Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          controller: _controller, expands: true, minLines: null, maxLines: null,
          keyboardType: TextInputType.multiline, autocorrect: false, enableSuggestions: false,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.45),
          decoration: InputDecoration(
            hintText: '<svg ...>', filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
      )),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: FilledButton.icon(
          onPressed: _saving ? null : _saveCopy,
          icon: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save_as_rounded),
          label: Text(_saving ? 'A guardar…' : 'Guardar como cópia'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
        ),
      ),
    ]),
  );
}
