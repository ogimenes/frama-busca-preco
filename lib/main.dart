import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() => runApp(MaterialApp(
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: const Color(0xFF0F172A)),
      home: MainNavigation(),
    ));

class MainNavigation extends StatefulWidget {
  @override
  _MainNavigationState createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  String serverIp = "192.168.127.5";
  int serverPort = 6500;
  List<Map<String, String>> historico = [];

  void adicionarAoLog(String ean, String desc, String preco) {
    setState(() {
      historico.insert(0, {
        "data": DateTime.now().toString().substring(0, 19),
        "ean": ean, "desc": desc, "preco": preco
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> _telas = [
      TelaConsulta(ip: serverIp, porta: serverPort, onResult: adicionarAoLog),
      TelaHistorico(logs: historico),
      TelaConfig(
        currentIp: serverIp, currentPort: serverPort,
        onSave: (ip, porta) => setState(() { serverIp = ip; serverPort = porta; }),
      ),
    ];

    return Scaffold(
      body: _telas[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner), label: 'Consultar'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Histórico'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Config'),
        ],
      ),
    );
  }
}

class TelaConsulta extends StatefulWidget {
  final String ip; final int porta; final Function(String, String, String) onResult;
  TelaConsulta({required this.ip, required this.porta, required this.onResult});
  @override
  _TelaConsultaState createState() => _TelaConsultaState();
}

class _TelaConsultaState extends State<TelaConsulta> {
  bool isManual = false; String descricao = ""; String preco = ""; bool showModal = false;
  final TextEditingController _manualCtrl = TextEditingController();

  void comunicarServidor(String codigo) async {
    setState(() { descricao = "CONSULTANDO..."; preco = "---"; showModal = true; });
    try {
      final socket = await Socket.connect(widget.ip, widget.porta, timeout: Duration(seconds: 2));
      socket.write("#ID|01#");
      await Future.delayed(Duration(milliseconds: 300));
      socket.write("#$codigo#");
      socket.listen((data) {
        String res = latin1.decode(data);
        if (res.contains('|')) {
          var partes = res.split('#').firstWhere((p) => p.contains('|')).split('|');
          String d = partes[0].trim().toUpperCase(); String p = partes[1].trim();
          setState(() { descricao = d; preco = p; });
          widget.onResult(codigo, d, p);
        }
        socket.destroy();
      });
    } catch (e) {
      setState(() { descricao = "ERRO DE CONEXÃO"; preco = "OFFLINE"; });
    }
    Future.delayed(Duration(seconds: 3), () => setState(() => showModal = false));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 60),
        Text("FRAMA BUSCA PREÇO", style: TextStyle(color: Color(0xFF60A5FA), fontSize: 26, fontWeight: FontWeight.bold)),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (!isManual) MobileScanner(onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isNotEmpty && !showModal) { comunicarServidor(barcodes.first.rawValue ?? ""); }
              }),
              if (isManual) Padding(
                padding: EdgeInsets.all(40),
                child: TextField(
                  controller: _manualCtrl,
                  decoration: InputDecoration(labelText: "Digite o EAN", filled: true, border: OutlineInputBorder()),
                  onSubmitted: (val) => comunicarServidor(val),
                ),
              ),
              if (showModal) Card(
                color: Colors.white,
                child: Padding(
                  padding: EdgeInsets.all(30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(descricao, style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                      SizedBox(height: 15),
                      Text(preco, style: TextStyle(color: Colors.blue, fontSize: 45, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () => setState(() => isManual = !isManual),
          child: Text(isManual ? "ATIVAR CÂMERA" : "DIGITAÇÃO MANUAL", style: TextStyle(color: Colors.white54, fontSize: 12)),
        ),
        Padding(
          padding: EdgeInsets.all(10),
          child: Text("desenvolvido por Matheus Gimenes", style: TextStyle(color: Colors.white24, fontSize: 10)),
        ),
      ],
    );
  }
}

class TelaHistorico extends StatelessWidget {
  final List<Map<String, String>> logs;
  TelaHistorico({required this.logs});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Histórico LJ27"), backgroundColor: Colors.transparent),
      body: ListView.builder(
        itemCount: logs.length,
        itemBuilder: (context, i) => ListTile(
          title: Text(logs[i]['desc']!),
          subtitle: Text("${logs[i]['ean']} - ${logs[i]['data']}"),
          trailing: Text(logs[i]['preco']!, style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 18)),
        ),
      ),
    );
  }
}

class TelaConfig extends StatefulWidget {
  final String currentIp; final int currentPort; final Function(String, int) onSave;
  TelaConfig({required this.currentIp, required this.currentPort, required this.onSave});
  @override
  _TelaConfigState createState() => _TelaConfigState();
}

class _TelaConfigState extends State<TelaConfig> {
  bool autenticado = false;
  final TextEditingController _passCtrl = TextEditingController();
  final TextEditingController _ipCtrl = TextEditingController();
  final TextEditingController _portCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    if (!autenticado) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(50),
          child: TextField(
            controller: _passCtrl,
            decoration: InputDecoration(labelText: "Senha de Acesso", border: OutlineInputBorder()),
            obscureText: true,
            onChanged: (val) { if (val == "1342") setState(() => autenticado = true); },
          ),
        ),
      );
    }
    _ipCtrl.text = widget.currentIp; _portCtrl.text = widget.currentPort.toString();
    return Scaffold(
      appBar: AppBar(title: Text("Configurações Técnicas")),
      body: Padding(
        padding: EdgeInsets.all(30),
        child: Column(
          children: [
            TextField(controller: _ipCtrl, decoration: InputDecoration(labelText: "IP do Servidor")),
            SizedBox(height: 10),
            TextField(controller: _portCtrl, decoration: InputDecoration(labelText: "Porta")),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: () { widget.onSave(_ipCtrl.text, int.parse(_portCtrl.text)); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Salvo!"))); },
              child: Text("SALVAR CONFIGURAÇÕES"),
            )
          ],
        ),
      ),
    );
  }
}
