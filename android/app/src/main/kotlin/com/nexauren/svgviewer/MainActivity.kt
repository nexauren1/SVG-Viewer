package com.nexauren.svgviewer

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.DocumentsContract
import android.database.Cursor
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import java.io.BufferedReader
import java.io.InputStreamReader
import java.nio.charset.StandardCharsets

class MainActivity : FlutterActivity() {
    private val channelName = "svg_viewer/storage"
    private val prefsName = "svg_viewer_prefs"
    private var channel: MethodChannel? = null
    private var folderResult: MethodChannel.Result? = null
    private var saveResult: MethodChannel.Result? = null
    private var pendingSvgContent: String? = null
    private lateinit var folderPicker: ActivityResultLauncher<Uri?>
    private lateinit var savePicker: ActivityResultLauncher<String>

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        folderPicker = registerForActivityResult(ActivityResultContracts.OpenDocumentTree()) { uri ->
            val result = folderResult
            folderResult = null
            if (uri == null) {
                result?.success(emptyList<Map<String, String>>())
                return@registerForActivityResult
            }
            try {
                try {
                    contentResolver.takePersistableUriPermission(
                        uri,
                        Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                    )
                } catch (_: SecurityException) {
                    contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                getSharedPreferences(prefsName, MODE_PRIVATE).edit()
                    .putString("tree_uri", uri.toString()).apply()
                result?.success(scanSvgFiles(uri))
            } catch (e: Exception) {
                result?.error("SCAN_FAILED", e.localizedMessage ?: "Não foi possível pesquisar a pasta.", null)
            }
        }

        savePicker = registerForActivityResult(ActivityResultContracts.CreateDocument("image/svg+xml")) { uri ->
            val result = saveResult
            saveResult = null
            val content = pendingSvgContent
            pendingSvgContent = null
            if (uri == null || content == null) {
                result?.success(false)
                return@registerForActivityResult
            }
            try {
                contentResolver.openOutputStream(uri, "wt")?.use { output ->
                    output.write(content.toByteArray(StandardCharsets.UTF_8))
                    output.flush()
                } ?: throw IllegalStateException("Não foi possível escrever no ficheiro.")
                result?.success(true)
            } catch (e: Exception) {
                result?.error("SAVE_FAILED", e.localizedMessage ?: "Falha ao guardar o SVG.", null)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "hasSavedFolder" -> {
                    val saved = getSharedPreferences(prefsName, MODE_PRIVATE).getString("tree_uri", null)
                    result.success(saved != null)
                }
                "selectFolderAndScan" -> {
                    if (folderResult != null) {
                        result.error("BUSY", "Já existe uma seleção de pasta em curso.", null)
                    } else {
                        folderResult = result
                        folderPicker.launch(null)
                    }
                }
                "rescan" -> {
                    val saved = getSharedPreferences(prefsName, MODE_PRIVATE).getString("tree_uri", null)
                    if (saved == null) {
                        result.error("NO_FOLDER", "Seleciona uma pasta primeiro.", null)
                    } else {
                        try {
                            result.success(scanSvgFiles(Uri.parse(saved)))
                        } catch (e: Exception) {
                            result.error("SCAN_FAILED", e.localizedMessage ?: "Não foi possível pesquisar a pasta.", null)
                        }
                    }
                }
                "readDocument" -> {
                    val rawUri = call.argument<String>("uri")
                    if (rawUri.isNullOrBlank()) {
                        result.error("BAD_URI", "Endereço do documento inválido.", null)
                    } else {
                        try {
                            val text = contentResolver.openInputStream(Uri.parse(rawUri))?.use { input ->
                                BufferedReader(InputStreamReader(input, StandardCharsets.UTF_8)).readText()
                            } ?: throw IllegalStateException("Não foi possível abrir o ficheiro.")
                            if (text.toByteArray(StandardCharsets.UTF_8).size > 15 * 1024 * 1024) {
                                throw IllegalArgumentException("O SVG é demasiado grande para abrir no editor.")
                            }
                            result.success(text)
                        } catch (e: Exception) {
                            result.error("READ_FAILED", e.localizedMessage ?: "Não foi possível ler o SVG.", null)
                        }
                    }
                }
                "saveSvgCopy" -> {
                    val name = call.argument<String>("name") ?: "edited.svg"
                    val content = call.argument<String>("content")
                    if (content == null) {
                        result.error("NO_CONTENT", "Não há conteúdo para guardar.", null)
                    } else if (saveResult != null) {
                        result.error("BUSY", "Já existe uma gravação em curso.", null)
                    } else {
                        pendingSvgContent = content
                        saveResult = result
                        savePicker.launch(if (name.lowercase().endsWith(".svg")) name else "$name.svg")
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun scanSvgFiles(treeUri: Uri): List<Map<String, String>> {
        val rootId = DocumentsContract.getTreeDocumentId(treeUri)
        val results = mutableListOf<Map<String, String>>()
        val visited = mutableSetOf<String>()
        scanDirectory(treeUri, rootId, results, visited, 0)
        return results.sortedBy { it["name"]?.lowercase() ?: "" }
    }

    private fun scanDirectory(
        treeUri: Uri,
        parentDocumentId: String,
        output: MutableList<Map<String, String>>,
        visited: MutableSet<String>,
        depth: Int
    ) {
        if (depth > 16 || output.size >= 10000 || !visited.add(parentDocumentId)) return
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, parentDocumentId)
        val columns = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE
        )
        var cursor: Cursor? = null
        try {
            cursor = contentResolver.query(childrenUri, columns, null, null, null)
            cursor?.use { c ->
                val idIndex = c.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
                val nameIndex = c.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
                val mimeIndex = c.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_MIME_TYPE)
                while (c.moveToNext() && output.size < 10000) {
                    val id = c.getString(idIndex) ?: continue
                    val name = c.getString(nameIndex) ?: "untitled"
                    val mime = c.getString(mimeIndex) ?: ""
                    if (mime == DocumentsContract.Document.MIME_TYPE_DIR) {
                        scanDirectory(treeUri, id, output, visited, depth + 1)
                    } else if (name.lowercase().endsWith(".svg") || mime == "image/svg+xml") {
                        val documentUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, id)
                        output.add(mapOf("name" to name, "uri" to documentUri.toString()))
                    }
                }
            }
        } catch (e: SecurityException) {
            // A provider may hide protected subfolders. Continue with accessible documents.
        } finally {
            cursor?.close()
        }
    }
}
