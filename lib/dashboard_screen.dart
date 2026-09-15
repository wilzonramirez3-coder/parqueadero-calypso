import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<dynamic> parqueadero = [];
  bool isLoading = true;
  String searchQuery = '';
  String filtroTipo = 'Todos';
  bool isGridView = true;
  final String policiaNumero = "+573052746650";
  final int totalCupos = 35;

  // Controladores para el formulario
  final TextEditingController _cupoController = TextEditingController();
  final TextEditingController _placaController = TextEditingController();
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  String _tipoSeleccionado = 'PASAJERO';

  // Canal para tiempo real
  RealtimeChannel? _channel;

  @override
  void dispose() {
    _channel?.unsubscribe(); // ✅ Limpieza segura
    _cupoController.dispose();
    _placaController.dispose();
    _nombreController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    cargarDatos(mostrarMensaje: false);
    _suscribirseCambios();
  }

  void _suscribirseCambios() {
    _channel = Supabase.instance.client
        .channel('parqueadero_changes')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'parqueadero',
        callback: (_) => cargarDatos(mostrarMensaje: false),
      )
      ..subscribe();
  }

  Future<void> cargarDatos({bool mostrarMensaje = false}) async {
    setState(() => isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('parqueadero')
          .select()
          .order('spot');
      setState(() {
        parqueadero = response;
        isLoading = false;
      });
      if (mostrarMensaje && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Datos actualizados'), duration: Duration(seconds: 2), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al cargar: $e")),
        );
      }
    }
  }

  Future<void> guardarNuevoCupo() async {
    final cupo = _cupoController.text.trim();
    final placa = _placaController.text.trim().toUpperCase();
    final nombre = _nombreController.text.trim();
    final telefono = _telefonoController.text.trim();

    if (cupo.isEmpty || placa.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Cupo y Placa son obligatorios'), backgroundColor: Colors.orange),
      );
      return;
    }

    final cupoInt = int.tryParse(cupo);
    if (cupoInt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Cupo debe ser un número válido'), backgroundColor: Colors.orange),
      );
      return;
    }

    final cupoOcupado = parqueadero.any((r) => r['spot'] == cupoInt);
    if (cupoOcupado) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Ese cupo ya está ocupado'), backgroundColor: Colors.orange),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      await Supabase.instance.client.from('parqueadero').insert({
        'spot': cupoInt,
        'plate': placa,
        'name': nombre,
        'phone': telefono,
        'type': _tipoSeleccionado,
      });

      if (mounted) Navigator.pop(context);
      _limpiarFormulario();
      await cargarDatos(mostrarMensaje: false);

      messenger.showSnackBar(
        const SnackBar(content: Text('✅ Cupo registrado correctamente'), backgroundColor: Colors.green),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('❌ Error al guardar: $e')));
    }
  }

  Future<void> liberarCupo(int cupo) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("🗑️ Liberar Cupo", style: TextStyle(color: Colors.black)),
        content: Text("¿Estás seguro de que quieres liberar el cupo #$cupo?"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancelar", style: TextStyle(color: Colors.black)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("SÍ, LIBERAR", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await Supabase.instance.client.from('parqueadero').delete().eq('spot', cupo);
      await cargarDatos(mostrarMensaje: false);
      messenger.showSnackBar(const SnackBar(content: Text('✅ Cupo liberado correctamente'), backgroundColor: Colors.green));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('❌ Error al liberar: $e')));
    }
  }

  void _limpiarFormulario() {
    _cupoController.clear();
    _placaController.clear();
    _nombreController.clear();
    _telefonoController.clear();
    setState(() => _tipoSeleccionado = 'PASAJERO');
  }

  void _mostrarFormularioNuevoCupo() {
    _limpiarFormulario();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, left: 24, right: 24, top: 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.add_circle, color: Colors.green, size: 32),
                  const SizedBox(width: 12),
                  const Text(
                    "NUEVO CUPO",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildInputField(_cupoController, 'Número de Cupo', Icons.confirmation_number, TextInputType.number),
              _buildInputField(_placaController, 'Placa', Icons.directions_car),
              _buildInputField(_nombreController, 'Nombre del Dueño', Icons.person),
              _buildInputField(_telefonoController, 'Teléfono', Icons.phone, TextInputType.phone),
              const SizedBox(height: 10),
              const Text("Tipo de cupo:", style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildTipoOption('PASAJERO', Colors.orange)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildTipoOption('FIJO', const Color(0xFF1565C0))),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: guardarNuevoCupo,
                  icon: const Icon(Icons.save),
                  label: const Text("GUARDAR CUPO", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(TextEditingController controller, String hint, IconData icon, [TextInputType tipo = TextInputType.text]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        keyboardType: tipo,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: Icon(icon, color: Colors.red),
          filled: true,
          fillColor: const Color(0xFF2C2C2C),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildTipoOption(String tipo, Color color) {
    final bool activo = _tipoSeleccionado == tipo;
    return GestureDetector(
      onTap: () => setState(() => _tipoSeleccionado = tipo),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: activo ? color.withOpacity(0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: activo ? color : Colors.white24, width: 1.5),
        ),
        child: Center(
          child: Text(
            tipo,
            style: TextStyle(color: activo ? color : Colors.white54, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Future<void> _llamarNumero(String numero) async {
    final uri = Uri.parse('tel:$numero');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir la app de teléfono')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al llamar: $e')));
    }
  }

  void llamarEmergencia() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("🚨 EMERGENCIA", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        content: Text("¿Llamar al número de emergencia?\nNúmero: $policiaNumero"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar", style: TextStyle(color: Colors.black))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _llamarNumero(policiaNumero);
            },
            child: const Text("LLAMAR AHORA", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBar(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color.withOpacity(0.9), color.withOpacity(0.6)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
              Text(title, style: const TextStyle(fontSize: 10, color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCupoFijo(Map<String, dynamic> registro) {
    final plate = registro['plate'] ?? 'SIN PLACA';
    final cupo = registro['spot'].toString();
    return GestureDetector(
      onTap: () => mostrarDetalles(registro),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF0D47A1)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white, width: 1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.directions_car, color: Colors.white, size: 20),
            const SizedBox(height: 2),
            Text("#$cupo", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
            const Divider(height: 3, color: Colors.white54),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(plate, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCupoPasajero(Map<String, dynamic> registro) {
    final plate = registro['plate'] ?? 'SIN PLACA';
    final cupo = registro['spot'].toString();
    return GestureDetector(
      onTap: () => mostrarDetalles(registro),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFFF6F00), Color(0xFFE65100)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white, width: 1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.directions_car, color: Colors.white, size: 20),
            const SizedBox(height: 2),
            Text("#$cupo", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
            const Divider(height: 3, color: Colors.white54),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(plate, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCupoVacio(int cupoNumero) {
    return GestureDetector(
      onTap: () => _mostrarFormularioNuevoCupo(),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.green.withOpacity(0.3), Colors.green.withOpacity(0.5)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(height: 2),
            Text("LIBRE #$cupoNumero", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildListItem(Map<String, dynamic> registro) {
    final plate = registro['plate'] ?? 'SIN PLACA';
    final cupo = registro['spot'].toString();
    final tipo = registro['type'] ?? 'PASAJERO';
    final isFijo = tipo == 'FIJO';
    return GestureDetector(
      onTap: () => mostrarDetalles(registro),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: isFijo ? [const Color(0xFF1565C0), const Color(0xFF0D47A1)] : [const Color(0xFFFF6F00), const Color(0xFFE65100)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white, width: 1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.directions_car, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Cupo #$cupo", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(isFijo ? 'FIJO' : 'PASAJERO', style: TextStyle(fontSize: 12, color: Colors.white70)),
                    const SizedBox(height: 4),
                    Text(plate, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  List<dynamic> getFilteredCupos() {
    List<dynamic> resultados = List.from(parqueadero);
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      resultados = resultados.where((r) {
        final plate = r['plate']?.toLowerCase() ?? '';
        final nombre = r['name']?.toLowerCase() ?? '';
        final spot = r['spot']?.toString().toLowerCase() ?? '';
        return plate.contains(query) || nombre.contains(query) || spot.contains(query);
      }).toList();
    }
    if (filtroTipo != 'Todos') {
      if (filtroTipo == 'Libres') {
        resultados = [];
      } else {
        final tipoBD = filtroTipo == 'Fijos' ? 'FIJO' : 'PASAJERO';
        resultados = resultados.where((r) => r['type'] == tipoBD).toList();
      }
    }
    return resultados;
  }

  int _getTotalItemsToShow(int filteredCount) {
    if (filtroTipo == 'Fijos' || filtroTipo == 'Pasajeros') return filteredCount;
    else if (filtroTipo == 'Libres') return totalCupos - parqueadero.length;
    else return filteredCount + (totalCupos - parqueadero.length);
  }

  List<int> _cuposLibres() {
    final ocupados = parqueadero.map((r) => r['spot'] is int ? r['spot'] : int.tryParse(r['spot'].toString()) ?? -1).toSet();
    return [for (var i = 1; i <= totalCupos; i++) if (!ocupados.contains(i)) i];
  }

  String _obtenerFechaHora() {
    final now = DateTime.now();
    final dia = now.day.toString().padLeft(2, '0');
    final mes = now.month.toString().padLeft(2, '0');
    final anio = now.year;
    final hora = now.hour.toString().padLeft(2, '0');
    final min = now.minute.toString().padLeft(2, '0');
    return '$dia/$mes/$anio $hora:$min';
  }

  @override
  Widget build(BuildContext context) {
    final filteredCupos = getFilteredCupos();
    final fijos = parqueadero.where((r) => r['type'] == 'FIJO').length;
    final pasajeros = parqueadero.where((r) => r['type'] == 'PASAJERO').length;
    final disponibles = totalCupos - parqueadero.length;
    final libres = _cuposLibres();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(4.0),
          child: FloatingActionButton(
            onPressed: llamarEmergencia,
            backgroundColor: Colors.white,
            elevation: 6,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.red, width: 2)),
            child: const Icon(Icons.warning_amber_rounded, size: 28, color: Colors.black),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.directions_car, color: Colors.red, size: 24),
            const SizedBox(width: 8),
            Text(
              "PARQUEADERO CALYPSO",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.red,
                fontStyle: FontStyle.italic,
                letterSpacing: 0.8,
                shadows: [Shadow(color: Colors.red.withOpacity(0.6), offset: const Offset(2, 2), blurRadius: 6)],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.red, size: 24), onPressed: () => cargarDatos(mostrarMensaje: true), tooltip: "Actualizar datos"),
          IconButton(icon: Icon(isGridView ? Icons.list : Icons.grid_view, color: Colors.red, size: 24), onPressed: () => setState(() => isGridView = !isGridView), tooltip: isGridView ? "Vista Lista" : "Vista Grid"),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, -2))],
            ),
            child: Column(
              children: [
                Center(
                  child: SizedBox(
                    width: 280,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2C),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.red.withOpacity(0.6), width: 2),
                        boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: TextField(
                        onChanged: (value) => setState(() => searchQuery = value),
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(hintText: "🔍 Buscar placa, dueño o cupo...", hintStyle: TextStyle(color: Colors.white54, fontSize: 13), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 14), prefixIcon: Icon(Icons.search, color: Colors.red)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (!isLoading && parqueadero.isNotEmpty)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildFiltroButton('Todos', Icons.filter_list, Colors.white),
                      _buildFiltroButton('Fijos', Icons.house, const Color(0xFF1565C0)),
                      _buildFiltroButton('Pasajeros', Icons.person, const Color(0xFFFF6F00)),
                      _buildFiltroButton('Libres', Icons.check_circle, Colors.green),
                    ],
                  ),
                const SizedBox(height: 14),
                if (filtroTipo == 'Todos' && !isLoading && parqueadero.isNotEmpty)
                  Row(
                    children: [
                      _buildStatBar("Fijos", "$fijos", Icons.house, const Color(0xFF1565C0)),
                      _buildStatBar("Pasajeros", "$pasajeros", Icons.person, const Color(0xFFFF6F00)),
                      _buildStatBar("Disponibles", "$disponibles", Icons.check_circle, Colors.green),
                      _buildStatBar("Total", "$totalCupos", Icons.car_rental, Colors.purple),
                    ],
                  ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.red))
                : filteredCupos.isEmpty && filtroTipo != 'Libres'
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.car_rental, size: 64, color: Colors.white24),
                            const SizedBox(height: 16),
                            Text("No se encontraron cupos", style: TextStyle(color: Colors.white54, fontSize: 16)),
                            const SizedBox(height: 8),
                            Text("Agrega un nuevo cupo con el botón +", style: TextStyle(color: Colors.white38, fontSize: 12)),
                          ],
                        ),
                      )
                    : isGridView
                        ? Padding(
                            padding: const EdgeInsets.all(6),
                            child: GridView.builder(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 0.6, crossAxisSpacing: 4, mainAxisSpacing: 4),
                              itemCount: _getTotalItemsToShow(filteredCupos.length),
                              itemBuilder: (context, index) {
                                if (index < filteredCupos.length) {
                                  final registro = filteredCupos[index];
                                  final tipo = registro['type'];
                                  if (tipo == 'FIJO') return _buildCupoFijo(registro);
                                  else return _buildCupoPasajero(registro);
                                } else {
                                  if (filtroTipo == 'Todos' || filtroTipo == 'Libres') {
                                    final libreIndex = index - filteredCupos.length;
                                    if (libreIndex < libres.length) return _buildCupoVacio(libres[libreIndex]);
                                  }
                                  return const SizedBox.shrink();
                                }
                              },
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(10),
                            itemCount: filteredCupos.length,
                            itemBuilder: (context, index) => _buildListItem(filteredCupos[index]),
                          ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Align(alignment: Alignment.bottomRight, child: Text("By Wilson R.", style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.4), fontStyle: FontStyle.italic, fontWeight: FontWeight.w300, letterSpacing: 0.5))),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarFormularioNuevoCupo,
        backgroundColor: Colors.green,
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Agregar Nuevo Cupo',
      ),
    );
  }

  Widget _buildFiltroButton(String texto, IconData icon, Color color) {
    final bool activo = filtroTipo == texto;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: GestureDetector(
          onTap: () => setState(() => filtroTipo = texto),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: activo ? color.withOpacity(0.2) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: activo ? color : Colors.white.withOpacity(0.2), width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: activo ? color : Colors.white70),
                const SizedBox(width: 4),
                Text(texto, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: activo ? color : Colors.white70)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void mostrarDetalles(Map<String, dynamic> registro) {
    final tipo = registro['type'];
    final esFijo = tipo == 'FIJO';
    final cupo = registro['spot'].toString();
    final fechaActual = _obtenerFechaHora();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.car_rental, color: Colors.red, size: 32),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Cupo #$cupo", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text(esFijo ? 'FIJO' : 'PASAJERO', style: TextStyle(fontSize: 14, color: esFijo ? const Color(0xFF1565C0) : const Color(0xFFFF6F00), fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: QrImageView(
                  data: 'PARQUEADERO CALYPSO\nCupo: $cupo\nPlaca: ${registro['plate'] ?? 'SIN_PLACA'}\nDueño: ${registro['name'] ?? 'SIN_NOMBRE'}\nGenerado: $fechaActual',
                  version: QrVersions.auto,
                  size: 120.0,
                  foregroundColor: Colors.black,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 16),
            _buildDetailRow("PLACA", registro['plate'] ?? 'Sin placa'),
            _buildDetailRow("DUEÑO", registro['name'] ?? 'Sin nombre'),
            _buildDetailRow("TELÉFONO", registro['phone'] ?? 'Sin teléfono'),
            const SizedBox(height: 20),
            if (registro['phone'] != null && registro['phone'] != '')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _llamarNumero(registro['phone'].toString()),
                  icon: const Icon(Icons.call, size: 20),
                  label: const Text("Llamar al dueño", style: TextStyle(fontSize: 14)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => liberarCupo(int.tryParse(cupo) ?? 0),
                icon: const Icon(Icons.delete_outline, size: 20),
                label: const Text("LIBERAR CUPO", style: TextStyle(fontSize: 14)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 70, child: Text("$label:", style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white70, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: Colors.white))),
        ],
      ),
    );
  }
}