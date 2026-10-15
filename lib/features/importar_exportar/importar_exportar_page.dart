import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ficheiros/guardar_ficheiro.dart';
import '../../core/formatos.dart';
import '../../data/providers.dart';
import '../../domain/modelos.dart';
import '../../import/exportar.dart';
import '../../import/importar_seed.dart';
import '../../import/seed_modelo.dart';
import '../shell/shell.dart';

/// Nesta fase só há JSON; CSV, Excel e PDF entram na Fase 1.
enum _OQueImportar { copiaCompleta }

enum _Formato { json }

class ImportarExportarPage extends ConsumerStatefulWidget {
  const ImportarExportarPage({super.key});

  @override
  ConsumerState<ImportarExportarPage> createState() =>
      _ImportarExportarPageState();
}

class _ImportarExportarPageState extends ConsumerState<ImportarExportarPage> {
  _OQueImportar _oQue = _OQueImportar.copiaCompleta;
  _Formato _formatoImportar = _Formato.json;
  _Formato _formatoExportar = _Formato.json;

  bool _ocupado = false;
  String? _estado;
  ResultadoImportacao? _resultado;

  void _mostrar(String texto) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(texto)));

  Future<void> _importar() async {
    final ficheiros = await FilePicker.pickFiles(
      dialogTitle: 'Escolher cópia JSON',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (ficheiros.isEmpty || !mounted) return;

    setState(() {
      _ocupado = true;
      _estado = 'A ler o ficheiro…';
      _resultado = null;
    });
    try {
      final texto = utf8.decode(await ficheiros.first.readAsBytes());
      final seed = SeedFicheiro.lerTexto(texto);

      final dados = ref.read(dadosRepositoryProvider);
      var substituir = false;
      if (await dados.temDados()) {
        if (!mounted) return;
        substituir = await _confirmarSubstituir() ?? false;
        if (!substituir) {
          setState(() => _estado = 'Importação cancelada.');
          return;
        }
      }

      setState(
        () => _estado =
            'A importar ${seed.compras.length} compras e '
            '${seed.artigos.length} artigos…',
      );
      final resultado = await ImportadorSeed(
        dados: dados,
        lojas: ref.read(lojasRepositoryProvider),
      ).importar(seed, substituir: substituir);
      if (!mounted) return;
      setState(() {
        _resultado = resultado;
        _estado = null;
      });
    } on SeedInvalido catch (e) {
      if (!mounted) return;
      setState(() => _estado = null);
      await _mostrarErros(e.erros);
    } catch (e) {
      if (!mounted) return;
      setState(() => _estado = null);
      _mostrar('A importação falhou e nada foi alterado: $e');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<bool?> _confirmarSubstituir() => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Substituir dados atuais?'),
      content: const Text(
        'Esta conta já tem dados. Se continuares, são apagados e substituídos '
        'pelos do ficheiro. Nada é duplicado.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Substituir'),
        ),
      ],
    ),
  );

  Future<void> _mostrarErros(List<String> erros) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Ficheiro inválido'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(child: Text(erros.join('\n'))),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
      ],
    ),
  );

  Future<void> _exportar() async {
    setState(() {
      _ocupado = true;
      _estado = 'A preparar a cópia…';
    });
    try {
      final tabelas = await ref.read(dadosRepositoryProvider).lerTudo();
      final texto = exportacaoParaTexto(montarExportacao(tabelas));
      await guardarTexto(
        'cabaz-mensal-${dataIso(DateTime.now())}.json',
        texto,
      );
    } catch (e) {
      if (mounted) _mostrar('Não foi possível exportar: $e');
    } finally {
      if (mounted) {
        setState(() {
          _ocupado = false;
          _estado = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Pagina(
      titulo: 'Importar e exportar',
      corpo: ConteudoCentrado(
        largura: 760,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Importar dados', style: tema.textTheme.titleLarge),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        DropdownMenu<_OQueImportar>(
                          label: const Text('O que importar'),
                          initialSelection: _oQue,
                          width: 260,
                          onSelected: (v) => setState(() => _oQue = v ?? _oQue),
                          dropdownMenuEntries: const [
                            DropdownMenuEntry(
                              value: _OQueImportar.copiaCompleta,
                              label: 'Cópia completa / histórico',
                            ),
                          ],
                        ),
                        DropdownMenu<_Formato>(
                          label: const Text('Formato'),
                          initialSelection: _formatoImportar,
                          width: 160,
                          onSelected: (v) => setState(
                            () => _formatoImportar = v ?? _formatoImportar,
                          ),
                          dropdownMenuEntries: const [
                            DropdownMenuEntry(
                              value: _Formato.json,
                              label: 'JSON',
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _ocupado ? null : _importar,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Escolher ficheiro .json'),
                    ),
                  ],
                ),
              ),
            ),
            if (_estado != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  if (_ocupado) ...[
                    const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(child: Text(_estado!)),
                ],
              ),
            ],
            if (_resultado != null) ...[
              const SizedBox(height: 16),
              ResumoImportacao(resultado: _resultado!),
            ],
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Exportar cópia', style: tema.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      'Guarda todos os dados num ficheiro que pode ser '
                      'importado outra vez.',
                      style: TextStyle(color: tema.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    DropdownMenu<_Formato>(
                      label: const Text('Formato'),
                      initialSelection: _formatoExportar,
                      width: 160,
                      onSelected: (v) => setState(
                        () => _formatoExportar = v ?? _formatoExportar,
                      ),
                      dropdownMenuEntries: const [
                        DropdownMenuEntry(value: _Formato.json, label: 'JSON'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _ocupado ? null : _exportar,
                      icon: const Icon(Icons.download),
                      label: const Text('Exportar cópia'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ResumoImportacao extends StatelessWidget {
  const ResumoImportacao({super.key, required this.resultado});

  final ResultadoImportacao resultado;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final r = resultado;
    Widget marca(bool? ok) => switch (ok) {
      true => Icon(Icons.check_circle, color: Colors.green.shade700),
      false => Icon(Icons.cancel, color: tema.colorScheme.error),
      null => const Icon(Icons.remove),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                marca(r.tudoOk),
                const SizedBox(width: 8),
                Text(
                  r.tudoOk ? 'Importação concluída' : 'Importação com diferenças',
                  style: tema.textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _Numero('Compras', formatarInteiro(r.contagens['compras'])),
                _Numero('Artigos', formatarInteiro(r.contagens['artigos'])),
                _Numero('Lojas', formatarInteiro(r.contagens['lojas'])),
                _Numero('Total', formatarCent(r.totalCent)),
                _Numero('Para rever', formatarInteiro(r.comprasRever)),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            for (final l in r.lojas)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: marca(l.ok),
                title: Text(l.nome),
                subtitle: Text(
                  '${l.nCompras} ${l.nCompras == 1 ? 'compra' : 'compras'}'
                  '${l.ok == false ? ' · esperado ${formatarCent(l.esperadoCent!)}' : ''}',
                ),
                trailing: Text(formatarCent(l.totalCent)),
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: marca(r.totalOk),
              title: const Text('Total global'),
              subtitle: r.totalOk == false
                  ? Text('esperado ${formatarCent(r.totalEsperadoCent!)}')
                  : null,
              trailing: Text(
                formatarCent(r.totalCent),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Numero extends StatelessWidget {
  const _Numero(this.rotulo, this.valor);

  final String rotulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          rotulo,
          style: tema.textTheme.labelMedium?.copyWith(
            color: tema.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(valor, style: tema.textTheme.headlineSmall),
      ],
    );
  }
}
