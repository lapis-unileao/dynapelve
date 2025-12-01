// =======================================================
// DINAMÔMETRO – VERSÃO FINAL (SEM SEXO + CAMPOS CENTRALIZADOS)
// =======================================================
import processing.serial.*;
import processing.pdf.*;
import java.util.Date;
import java.text.SimpleDateFormat;
import java.awt.Frame;
import processing.awt.PSurfaceAWT;

Serial porta;

// Variáveis principais
float forca = 0;
float suavizado = 0;
float picoAtual = 0;
float picoCongelado = 0.0;
float tempoCongelado = 0.0;

final float FORCA_MAX = 1.00;
final float LIMIAR = 0.01;
long inicioContracao = 0L;
float tempoContracaoAtual = 0.0;
boolean contraindo = false;

ArrayList<Sessao> todasSessoes = new ArrayList<Sessao>();
Sessao sessaoAtual;
ArrayList<Float> forceHistory = new ArrayList<Float>();
int maxHistory = 800;

int tela = 3; // começa no cadastro
boolean modoFullscreen = true;
PFont fTitulo, fValor, fNormal, fBotao;

// --- Cadastro Simplificado (sem sexo) ---
class Paciente {
  String nome = "";
  String idade = "";
}
Paciente pacienteAtual = new Paciente();
String campoAtivo = "";
boolean cadastroConcluido = false;

void setup() {
  size(1280, 720);    // Pode ser qualquer tamanho inicial

  // --- Maximizar a janela sem usar fullscreen ---
  surface.setResizable(true);
  Frame frame = (Frame) ((PSurfaceAWT.SmoothCanvas) surface.getNative()).getFrame();
  frame.setExtendedState(Frame.MAXIMIZED_BOTH);
  // ----------------------------------------------

  // resto do seu setup...

  surface.setTitle("Dinamômetro");
  fTitulo = createFont("Segoe UI Bold", 70);
  fValor = createFont("Segoe UI Bold", 110);
  fNormal = createFont("Segoe UI", 32);
  fBotao = createFont("Segoe UI Bold", 26);

  novaSessao();

  try {
    porta = new Serial(this, "COM4", 9600);
    porta.bufferUntil('\n');
    println("Arduino conectado na COM4");
  }
  catch (Exception e) {
    println("Modo SIMULAÇÃO – sem Arduino");
    porta = null;
  }
}

void draw() {
  background(#0A0E2A);

  if (porta == null) {
    float t = millis() / 1000.0;
    float sim = 0.02 * (0.5 + 0.5 * sin(t*2.0)) + 0.005 * noise(t*0.5);
    if (frameCount % 300 < 30) sim += 0.2 * abs(sin(t*10));
    forca = constrain(sim, 0, FORCA_MAX);
    suavizado = lerp(suavizado, forca, 0.15);
    if (suavizado > picoAtual) picoAtual = suavizado;
    atualizaEstadoContracao();
  }

  if (cadastroConcluido) desenharAbasModernas();
  desenharTituloESublinha();
  addToHistory(suavizado);

  if (tela == 0) telaAoVivo();
  else if (tela == 1) telaResultados();
  else if (tela == 2) telaHistoricos();
  else if (tela == 3) telaCadastro();
}

void desenharAbasModernas() {
  String[] nomes = {"AO VIVO", "RESULTADOS", "HISTÓRICOS"};
  int quantidade = nomes.length;
  int larguraAba = 200;
  int alturaAba = 60;
  int espacamento = 20;
  int larguraTotal = quantidade * larguraAba + (quantidade - 1) * espacamento;
  int inicioX = (width - larguraTotal) / 2;
  int y = 40;

  for (int i = 0; i < quantidade; i++) {
    int x = inicioX + i * (larguraAba + espacamento);
    boolean ativo = (tela == i);
    boolean hover = mouseX > x && mouseX < x + larguraAba && mouseY > y && mouseY < y + alturaAba;

    noStroke();
    fill(0, 60);
    rect(x + 2, y + 6, larguraAba, alturaAba, 35);

    fill(ativo ? #00FFC8 : (hover ? #1A1F3D : #141826));
    stroke(ativo ? #00FFC8 : #141826);
    strokeWeight(ativo ? 4 : 0);
    rect(x, y, larguraAba, alturaAba, 35);

    fill(ativo ? 0 : 255);
    textFont(fBotao);
    textAlign(CENTER, CENTER);
    text(nomes[i], x + larguraAba/2, y + alturaAba/2);
  }
}

void desenharTituloESublinha() {
  fill(255);
  textFont(fTitulo);
  textAlign(CENTER, TOP);
  textSize(36);
  text("", width/2, 120);
}

void telaAoVivo() {
  float valor = constrain(suavizado, 0, FORCA_MAX);
  float angulo = map(valor, 0, FORCA_MAX, -PI/2, PI*1.5);

  int gaugeX = width/2;
  int gaugeY = height/2 - 40;
// =====================================================
//   INDICADOR DE ESTABILIDADE DA CONTRAÇÃO
//   Verde = estável
//   Amarelo = oscilando
//   Vermelho = instável
// =====================================================

// Cálculo da variação dos últimos 15 frames
int n = 15;
float variacao = 0;

if (forceHistory.size() > n) {
  float minV = 999;
  float maxV = -999;

  for (int i = forceHistory.size() - n; i < forceHistory.size(); i++) {
    float v = forceHistory.get(i);
    if (v < minV) minV = v;
    if (v > maxV) maxV = v;
  }

  variacao = maxV - minV;
}

// Define cor
color corEstabilidade;

if (!contraindo) {
  corEstabilidade = color(80);  // cinza no repouso
} 
else if (variacao < 0.01) {
  corEstabilidade = color(#00FF77); // verde — estável
} 
else if (variacao < 0.03) {
  corEstabilidade = color(#FFD700); // amarelo — oscilando
} 
else {
  corEstabilidade = color(#FF4444); // vermelho — instável
}

// Desenho do indicador (barra horizontal estilizada)
int barraW = 260;
int barraH = 22;
int barraX = width/2 - barraW/2;
int barraY = gaugeY + 360;

fill(0, 60);
noStroke();
rect(barraX, barraY, barraW, barraH, 12);

fill(corEstabilidade);
rect(barraX, barraY, barraW, barraH, 12);

// Texto explicativo
fill(220);
textFont(fNormal);
textSize(22);
textAlign(CENTER, CENTER);

if (!contraindo)
  text("Estabilidade: repouso", width/2, barraY - 25);
else if (variacao < 0.01)
  text("Estabilidade: estável", width/2, barraY - 25);
else if (variacao < 0.03)
  text("Estabilidade: oscilando", width/2, barraY - 25);
else
  text("Estabilidade: instável", width/2, barraY - 25);

  // ================= GAUGE =================
  pushMatrix();
  translate(gaugeX, gaugeY);

  // Fundo
  noFill();
  stroke(#1E253A);
  strokeWeight(45);
  arc(0, 0, 320, 320, -PI/2, PI*1.5);

  // Barra ativa
  stroke(#00FFC8);
  strokeWeight(36);
  arc(0, 0, 320, 320, -PI/2, angulo);

  // Ponteiro
  pushMatrix();
  rotate(angulo);
  stroke(255);
  strokeWeight(5);
  line(0, 0, 115, 0);
  popMatrix();

  // Centro
  fill(#00FFC8);
  noStroke();
  circle(0, 0, 30);

  popMatrix();


  // ========== ÁREA DE TEXTO ==========  
  textAlign(CENTER, CENTER);

  // 🔥 DESCEMOS TUDO 140px 🔥
  int baseY = gaugeY + 220;   // <-- ANTES era +200 → AGORA está mais afastado


  // ----- Pico sessão -----
  fill(200);
  textFont(fNormal);
  textSize(22);
  text("Pico sessão: " + nf(picoAtual, 0, 2) + " kg", width/2, gaugeY - 200);
  // <-- também movido 40px acima, longe do anel


  // ----- Valor grande -----
  fill(255);
 textFont(fValor);
textSize(70);  // <<< novo tamanho do número grande
text(nf(valor, 0, 2), width/2, baseY);


  // ----- Unidade “kg” -----
  fill(#00FFC8);
  textFont(fNormal);
  textSize(40);
  text("kg", width/2 + 90, baseY);


  // ----- Status -----
  fill(contraindo ? #FF5555 : #00FFC8);
  textFont(fNormal);
  textSize(40);
  text(contraindo ? "CONTRAÇÃO ATIVA" : "REPOUSO", width/2, baseY + 80);


  // Tempo
  if (contraindo)
    tempoContracaoAtual = (millis() - inicioContracao) / 1000.0;
}

void telaResultados() {
  fill(255);
  textFont(fNormal);
  textSize(38);
  textAlign(CENTER, TOP);
  text("Resultados da Sessão Atual", width/2, 180);

  fill(#00D4FF);
  textFont(fValor);
  textSize(110);
  text(nf(picoCongelado, 0, 2) + " kg", width/2, 280);
  fill(200);
  textSize(32);
  text("Pico máximo alcançado", width/2, 410);

  fill(#FFD700);
  textSize(85);
  text(nf(tempoCongelado, 0, 1) + " s", width/2, 480);
  fill(200);
  textSize(30);
  text("Tempo total em contração", width/2, 570);
}

void telaHistoricos() {
  fill(255);
  textFont(fNormal);
  textSize(36);
  textAlign(CENTER, TOP);
  text("Histórico de Sessões (" + todasSessoes.size() + ")", width/2, 180);

  int y = 250;
  for (int i = todasSessoes.size()-1; i >= 0 && y < height-120; i--) {
    Sessao s = todasSessoes.get(i);
    fill(i == todasSessoes.size()-1 ? #00FFC8 : 200);
    textSize(26);
    text(s.data + " → " + nf(s.pico, 0, 2) + " kg (" + nf(s.tempo, 0, 1) + " s)", width/2, y);
    y += 50;
  }

  fill(#00FFC8);
  rect(width - 330, height - 110, 260, 60, 12);
  fill(0);
  textFont(fBotao);
  textSize(20);
  textAlign(CENTER, CENTER);
  text("Exportar tudo (PDF)", width - 200, height - 80);
}

// ====================== TELA DE CADASTRO (CENTRALIZADA E SEM SEXO) ======================
void telaCadastro() {
  fill(255);
  textFont(fTitulo);
  textSize(38);
  textAlign(CENTER, TOP);
  text("Cadastro do Paciente", width/2, 100);

  int campoW = 500;
  int campoH = 62;
  int espacoY = 100;
  int inicioY = 220;

  // Campo Nome
  desenharCampoCentralizado("Nome completo:", pacienteAtual.nome, width/2 - campoW/2, inicioY, campoW, campoH, "nome");
  
  // Campo Idade
  desenharCampoCentralizado("Idade:", pacienteAtual.idade, width/2 - campoW/2, inicioY + espacoY, campoW, campoH, "idade");

  // Botão Salvar
  int botaoY = inicioY + espacoY*2 + 50;
  fill(#00FFC8);
  stroke(#14A887);
  strokeWeight(4);
  rect(width/2 - 150, botaoY, 300, 70, 22);
  fill(0);
  textFont(fBotao);
  textSize(28);
  textAlign(CENTER, CENTER);
  text("Salvar Cadastro", width/2, botaoY + 35);

  // Cursor piscando
  if (!campoAtivo.equals("")) {
    textFont(fNormal);
    textSize(28);
    int tx = width/2 - campoW/2 + 20;
    int ty = campoAtivo.equals("nome") ? inicioY + campoH/2 :
             inicioY + espacoY + campoH/2;
    String current = campoAtivo.equals("nome") ? pacienteAtual.nome : pacienteAtual.idade;
    float tw = textWidth(current);
    if ((millis()/500) % 2 == 0) {
      stroke(255);
      strokeWeight(3);
      line(tx + tw, ty - 16, tx + tw, ty + 16);
    }
  }
}

void desenharCampoCentralizado(String label, String valor, int x, int y, int w, int h, String id) {
  boolean ativo = campoAtivo.equals(id);

  // Label
  fill(220);
  textFont(fNormal);
  textSize(26);
  textAlign(LEFT, BASELINE);
  text(label, x, y - 10);

  // Caixa
  fill(ativo ? #1A1F3D : #141826);
  stroke(ativo ? #00FFC8 : color(80));
  strokeWeight(ativo ? 4 : 3);
  rect(x, y, w, h, 16);

  // Texto digitado
  fill(255);
  textAlign(LEFT, CENTER);
  textSize(28);
  String display = valor;
  float maxW = w - 40;
  while (textWidth(display) > maxW && display.length() > 0) {
    display = "…" + display.substring(2);
  }
  text(display, x + 20, y + h/2);
}

void mousePressed() {
  if (cadastroConcluido) {
    String[] nomes = {"AO VIVO", "RESULTADOS", "HISTÓRICOS"};
    int quantidade = nomes.length;
    int larguraAba = 200;
    int alturaAba = 60;
    int espacamento = 20;
    int larguraTotal = quantidade * larguraAba + (quantidade - 1) * espacamento;
    int inicioX = (width - larguraTotal) / 2;
    int y = 40;

    for (int i = 0; i < quantidade; i++) {
      int x = inicioX + i * (larguraAba + espacamento);
      if (mouseX > x && mouseX < x + larguraAba && mouseY > y && mouseY < y + alturaAba) {
        tela = i;
        return;
      }
    }
  }

  if (tela == 2 && mouseX > width - 330 && mouseX < width - 70 && mouseY > height - 110 && mouseY < height - 50) {
    exportarTudoPDF();
  }

  if (tela == 3) {
    int campoW = 500;
    int campoH = 62;
    int inicioY = 220;
    int espacoY = 100;

    // Clique no campo Nome
    if (mouseX > width/2 - campoW/2 && mouseX < width/2 + campoW/2 &&
        mouseY > inicioY && mouseY < inicioY + campoH) {
      campoAtivo = "nome";
    }
    // Clique no campo Idade
    else if (mouseX > width/2 - campoW/2 && mouseX < width/2 + campoW/2 &&
             mouseY > inicioY + espacoY && mouseY < inicioY + espacoY + campoH) {
      campoAtivo = "idade";
    }
    // Botão Salvar
    else if (mouseX > width/2 - 150 && mouseX < width/2 + 150 &&
             mouseY > inicioY + espacoY*2 + 50 && mouseY < inicioY + espacoY*2 + 120) {
      if (pacienteAtual.nome.trim().length() > 0 && pacienteAtual.idade.trim().length() > 0) {
        cadastroConcluido = true;
        tela = 0;
        println("Cadastro salvo: " + pacienteAtual.nome + ", " + pacienteAtual.idade + " anos");
      } else {
        println("Preencha nome e idade!");
      }
      campoAtivo = "";
    } else {
      campoAtivo = "";
    }
  }
}

void keyTyped() {
  if (campoAtivo.equals("")) return;

  if (key == BACKSPACE || key == DELETE) {
    if (campoAtivo.equals("nome") && pacienteAtual.nome.length() > 0)
      pacienteAtual.nome = pacienteAtual.nome.substring(0, pacienteAtual.nome.length()-1);
    else if (campoAtivo.equals("idade") && pacienteAtual.idade.length() > 0)
      pacienteAtual.idade = pacienteAtual.idade.substring(0, pacienteAtual.idade.length()-1);
    return;
  }

  if (key == ENTER || key == RETURN) {
    campoAtivo = "";
    return;
  }

  if (key >= 32 && key <= 126) {
    if (campoAtivo.equals("nome")) {
      pacienteAtual.nome += key;
    } else if (campoAtivo.equals("idade") && key >= '0' && key <= '9') {
      pacienteAtual.idade += key;
    }
  }
}

void serialEvent(Serial p) {
  try {
    String msg = trim(p.readStringUntil('\n'));
    if (msg == null || msg.length() == 0) return;
    int idx = msg.indexOf(':');
    String num = idx != -1 ? msg.substring(idx+1) : msg;
    num = num.replace("}", "").replace(",", ".").trim();
    float v = Float.parseFloat(num);
    if (!Float.isNaN(v)) {
      forca = constrain(v, 0, FORCA_MAX);
      suavizado = lerp(suavizado, forca, 0.25);
      if (suavizado > picoAtual) picoAtual = suavizado;
      atualizaEstadoContracao();
    }
  } catch (Exception e) {}
}

void atualizaEstadoContracao() {
  if (suavizado > LIMIAR) {
    if (!contraindo) {
      contraindo = true;
      inicioContracao = millis();
      picoAtual = 0.0;
    }
  } else if (contraindo) {
    float dur = (millis() - inicioContracao) / 1000.0;
    if (picoAtual > 0.001 && dur > 0.01) {
      tempoCongelado = dur;
      picoCongelado = picoAtual;
      sessaoAtual.pico = picoCongelado;
      sessaoAtual.tempo = tempoCongelado;
      todasSessoes.add(sessaoAtual.copiar());
      println("Sessão salva: " + picoCongelado + " kg | " + tempoCongelado + " s");
      novaSessao();
    }
    contraindo = false;
  }
}

void addToHistory(float v) {
  forceHistory.add(v);
  if (forceHistory.size() > maxHistory) forceHistory.remove(0);
}

void exportarTudoPDF() {
  if (todasSessoes.size() == 0) return;
  String nome = "Relatorio_" + new SimpleDateFormat("yyyyMMdd_HHmmss").format(new Date()) + ".pdf";
  beginRecord(PDF, nome);
  background(255);
  fill(0);
  textAlign(CENTER);
  textSize(40);
  text("DINAMÔMETRO - Relatório de Sessões", width/2, 80);
  textSize(18);
  text("Paciente: " + pacienteAtual.nome + " | Idade: " + pacienteAtual.idade + " anos", width/2, 120);
  textSize(22);
  int y = 170;
  for (Sessao s : todasSessoes) {
    text(s.data + " → " + nf(s.pico, 0, 2) + " kg | " + nf(s.tempo, 0, 1) + " s", width/2, y);
    y += 30;
  }
  endRecord();
  println("PDF exportado: " + nome);
}

void novaSessao() {
  sessaoAtual = new Sessao();
  sessaoAtual.data = new SimpleDateFormat("dd/MM/yyyy HH:mm").format(new Date());
  sessaoAtual.pico = 0.0;
  sessaoAtual.tempo = 0.0;
  picoAtual = 0.0;
  contraindo = false;
}

class Sessao {
  String data = "";
  float pico = 0.0f;
  float tempo = 0.0f;
  Sessao copiar() {
    Sessao c = new Sessao();
    c.data = this.data;
    c.pico = this.pico;
    c.tempo = this.tempo;
    return c;
  }
}
