using System;
using System.IO;
using System.Linq;
using System.Text;
using System.Drawing;
using System.Reflection;
using System.Collections.Generic;
using System.Text.RegularExpressions;
using System.Web.Script.Serialization;
using System.Windows.Forms;

public class Card {
 public string id {get;set;} public string name {get;set;} public string kind {get;set;}
 public string description {get;set;} public int cost {get;set;} public int table_cost {get;set;}
 public bool dark {get;set;} public string icon {get;set;} public string[] directions {get;set;}
 public string effect_id {get;set;} public int value {get;set;} public string status {get;set;}
 public string face {get;set;} public string source_id {get;set;} public string legacy_description {get;set;}
 public override string ToString(){return name+"  ["+id+"]";}
}
public class Catalog { public int schema_version {get;set;} public List<Card> cards {get;set;} }
static class Data {
 public static readonly string[] Directions={"up_left","up","up_right","left","right","down_left","down","down_right"};
 public static readonly int[] DX={-1,0,1,-1,1,-1,0,1}, DY={-1,-1,-1,0,0,1,1,1};
 public static JavaScriptSerializer Json=new JavaScriptSerializer {MaxJsonLength=16000000};
 public static byte[] Bytes(string name){using(var s=Assembly.GetExecutingAssembly().GetManifestResourceStream(name)){if(s==null)throw new Exception("리소스 없음: "+name);using(var m=new MemoryStream()){s.CopyTo(m);return m.ToArray();}}}
 public static string Text(string name){return Encoding.UTF8.GetString(Bytes(name)).TrimStart('\uFEFF');}
 public static string[] Icons=Assembly.GetExecutingAssembly().GetManifestResourceNames().Where(n=>n.StartsWith("icon.")).Select(n=>n.Substring(5)).OrderBy(n=>n).ToArray();
 public static Catalog Parse(string s){var c=Json.Deserialize<Catalog>(s);Validate(c);return c;}
 public static void Validate(Catalog c){
  if(c==null||c.schema_version!=1||c.cards==null||c.cards.Count==0)throw new Exception("지원하지 않는 형식 또는 빈 카드 목록입니다.");
  var ids=new HashSet<string>();
  foreach(var x in c.cards){
   if(x==null||!Regex.IsMatch(x.id??"","^[a-z][a-z0-9_]{0,63}$")||!ids.Add(x.id))throw new Exception("ID는 중복 없는 영문 소문자·숫자·밑줄이어야 합니다.");
   if(String.IsNullOrWhiteSpace(x.name)||x.description==null||x.name.Length>100||x.description.Length>10000)throw new Exception(x.id+": 이름 또는 설명을 확인하세요.");
   if(x.cost < -1||x.cost>9999||x.table_cost < -1||x.table_cost>9999||Math.Abs((long)x.value)>9999)throw new Exception(x.id+": 숫자 범위 초과");
   if(!Icons.Contains(x.icon)||x.directions==null||x.directions.Any(d=>!Directions.Contains(d))||x.directions.Distinct().Count()!=x.directions.Length)throw new Exception(x.id+": 아이콘 또는 방향 오류");
   if(!new[]{"front","reverse"}.Contains(x.face)||!new[]{"pending","implemented"}.Contains(x.status))throw new Exception(x.id+": 상태 오류");
  }
 }
 public static void Save(string path,string text){var temp=path+".tmp";File.WriteAllText(temp,text,new UTF8Encoding(false));if(File.Exists(path))File.Replace(temp,path,null);else File.Move(temp,path);}
 public static void Html(Catalog c,string path){Validate(c);var icons=Icons.ToDictionary(n=>n,n=>"data:image/png;base64,"+Convert.ToBase64String(Bytes("icon."+n)));var json=Json.Serialize(new{cards=c.cards,icons=icons}).Replace("<","\\u003c").Replace(">","\\u003e").Replace("&","\\u0026");Save(path,Text("catalog.html").Replace("__LYNCO_DATA__",json));}
 static string Q(string s){return Json.Serialize(s??"");}
 public static string Export(Catalog c,string parent){
  Validate(c);string root=Path.Combine(parent,"LYNCO_Godot_"+DateTime.Now.ToString("yyyyMMdd_HHmmss"));while(Directory.Exists(root))root+="_1";
  string dir=Path.Combine(root,"lynco_cards");Directory.CreateDirectory(Path.Combine(dir,"cards"));Directory.CreateDirectory(Path.Combine(dir,"icons"));
  foreach(var n in new[]{"lynco_card_data.gd","lynco_card_loader.gd"})File.WriteAllText(Path.Combine(dir,n),Text(n),new UTF8Encoding(false));
  foreach(var n in c.cards.Select(x=>x.icon).Distinct())File.WriteAllBytes(Path.Combine(dir,"icons",n),Bytes("icon."+n));
  foreach(var x in c.cards){var s=new StringBuilder("[gd_resource type=\"Resource\" script_class=\"LyncoEditedCard\" load_steps=3 format=3]\n\n[ext_resource type=\"Script\" path=\"res://lynco_cards/lynco_card_data.gd\" id=\"1\"]\n[ext_resource type=\"Texture2D\" path=\"res://lynco_cards/icons/"+x.icon+"\" id=\"2\"]\n\n[resource]\nscript = ExtResource(\"1\")\nicon = ExtResource(\"2\")\n");
   var fields=new Dictionary<string,string>{{"id",x.id},{"card_name",x.name},{"description",x.description},{"kind",x.kind},{"face",x.face},{"source_id",x.source_id},{"effect_id",x.effect_id},{"status",x.status}};
   foreach(var f in fields)s.AppendLine(f.Key+" = "+Q(f.Value));
   s.AppendLine("action_cost = "+x.cost+"\ntable_cost = "+x.table_cost+"\neffect_value = "+x.value+"\ndark = "+(x.dark?"true":"false"));
   s.AppendLine("directions = PackedStringArray("+String.Join(", ",x.directions.Select(Q))+")");File.WriteAllText(Path.Combine(dir,"cards",x.id+".tres"),s.ToString(),new UTF8Encoding(false));
  }
  Save(Path.Combine(root,"cards.json"),Json.Serialize(c));File.WriteAllText(Path.Combine(root,"README.txt"),Text("README.txt"),Encoding.UTF8);return root;
 }
}
class Board:Control {
 public Card Card; public int Origin=14;
 public Board(){DoubleBuffered=true;BackColor=Color.White;MinimumSize=new Size(260,230);MouseClick+=(s,e)=>{int x=e.X/(Math.Max(1,Width/6)),y=e.Y/(Math.Max(1,Height/5));if(x<6&&y<5){Origin=y*6+x;Invalidate();}};}
 protected override void OnPaint(PaintEventArgs e){base.OnPaint(e);int w=Width/6,h=Height/5;for(int i=0;i<30;i++){bool hit=false;if(Card!=null)foreach(string d in Card.directions){int j=Array.IndexOf(Data.Directions,d);if(j>=0&&i%6==Origin%6+Data.DX[j]&&i/6==Origin/6+Data.DY[j])hit=true;}var r=new Rectangle(i%6*w+3,i/6*h+3,w-6,h-6);using(var b=new SolidBrush(i==Origin?Color.FromArgb(255,224,94):hit?Color.FromArgb(246,196,226):Color.FromArgb(239,242,242)))e.Graphics.FillRectangle(b,r);e.Graphics.DrawRectangle(Pens.Gray,r);if(i==Origin||hit)TextRenderer.DrawText(e.Graphics,i==Origin?"●":"○",Font,r,Color.Black,TextFormatFlags.HorizontalCenter|TextFormatFlags.VerticalCenter);}}
}
class Editor:Form {
 Catalog catalog; ListBox list=new ListBox(); TextBox search=new TextBox(); Dictionary<string,Control> fields=new Dictionary<string,Control>(); Dictionary<string,CheckBox> dirs=new Dictionary<string,CheckBox>(); Board board=new Board(); PictureBox picture=new PictureBox(); Label status=new Label(); bool loading,dirty; Card current;
 public Editor(Catalog c){catalog=c;Text="LYNCO 카드 편집기";Font=new Font("Malgun Gothic",10);Size=new Size(1380,860);MinimumSize=new Size(1120,740);BackColor=Color.White;
  var layout=new TableLayoutPanel{Dock=DockStyle.Fill,ColumnCount=3,RowCount=2,Padding=new Padding(16)};layout.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute,255));layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,60));layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,40));layout.RowStyles.Add(new RowStyle(SizeType.Absolute,52));layout.RowStyles.Add(new RowStyle(SizeType.Percent,100));Controls.Add(layout);
  var bar=new FlowLayoutPanel{Dock=DockStyle.Fill};layout.Controls.Add(bar,0,0);layout.SetColumnSpan(bar,3);
  AddButton(bar,"새 카드",()=>{if(!Commit())return;var x=Data.Json.Deserialize<Card>(Data.Json.Serialize(catalog.cards[0]));x.id=Unique("new_card");x.name="새 카드";x.description="효과 설계 대기";x.effect_id="pending";x.status="pending";x.directions=new string[0];x.legacy_description="";catalog.cards.Add(x);dirty=true;RefreshList(x);});
  AddButton(bar,"복제",()=>{if(!Commit())return;var x=Data.Json.Deserialize<Card>(Data.Json.Serialize(current));x.id=Unique(x.id+"_copy");catalog.cards.Add(x);dirty=true;RefreshList(x);});
  AddButton(bar,"삭제",()=>{if(catalog.cards.Count>1&&MessageBox.Show("선택한 카드를 삭제할까요?","삭제",MessageBoxButtons.YesNo)==DialogResult.Yes){catalog.cards.Remove(current);dirty=true;current=null;RefreshList(null);}});
  AddButton(bar,"JSON 열기",()=>{if(!CanLeave())return;using(var d=new OpenFileDialog{Filter="카드 JSON|*.json"})if(d.ShowDialog()==DialogResult.OK){catalog=Data.Parse(File.ReadAllText(d.FileName));current=null;dirty=false;RefreshList(null);}});
  AddButton(bar,"JSON 저장",()=>SaveJson());AddButton(bar,"Godot 내보내기",()=>{if(!Commit())return;using(var d=new FolderBrowserDialog{Description="새 내보내기 폴더를 만들 위치"})if(d.ShowDialog()==DialogResult.OK){var p=Data.Export(catalog,d.SelectedPath);MessageBox.Show(p,"내보내기 완료");}});
  AddButton(bar,"HTML 저장",()=>{if(!Commit())return;using(var d=new SaveFileDialog{Filter="HTML|*.html",FileName="카드_이름_효과_정리.html"})if(d.ShowDialog()==DialogResult.OK)Data.Html(catalog,d.FileName);});
  var left=new TableLayoutPanel{Dock=DockStyle.Fill,RowCount=2,ColumnCount=1,Padding=new Padding(0,0,14,0)};left.RowStyles.Add(new RowStyle(SizeType.Absolute,36));left.RowStyles.Add(new RowStyle(SizeType.Percent,100));search.Dock=DockStyle.Fill;list.Dock=DockStyle.Fill;list.HorizontalScrollbar=true;left.Controls.Add(search);left.Controls.Add(list);layout.Controls.Add(left,0,1);search.TextChanged+=(s,e)=>{if(Commit())RefreshList(current);};
  var form=new TableLayoutPanel{Dock=DockStyle.Fill,ColumnCount=2,AutoScroll=true,Padding=new Padding(4,0,18,0)};form.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute,110));form.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));layout.Controls.Add(form,1,1);
  Field(form,"id","ID",new TextBox());Field(form,"name","카드 이름",new TextBox());Field(form,"kind","분류",new TextBox());Field(form,"description","효과 설명",new TextBox{Multiline=true,Height=100,ScrollBars=ScrollBars.Vertical});
  Field(form,"cost","행동 비용",new NumericUpDown{Minimum=-1,Maximum=9999});Field(form,"table_cost","점수",new NumericUpDown{Minimum=-1,Maximum=9999});Field(form,"dark","카드 색상",new CheckBox{Text="검정색"});
  Field(form,"icon","심볼",Combo(Data.Icons));Field(form,"face","카드 면",Combo(new[]{"front","reverse"}));Field(form,"source_id","원본 ID",new TextBox());Field(form,"effect_id","효과 ID",new TextBox());Field(form,"value","효과 수치",new NumericUpDown{Minimum=-9999,Maximum=9999});Field(form,"status","구현 상태",Combo(new[]{"pending","implemented"}));
  var right=new TableLayoutPanel{Dock=DockStyle.Fill,ColumnCount=1,RowCount=6};right.RowStyles.Add(new RowStyle(SizeType.Absolute,100));right.RowStyles.Add(new RowStyle(SizeType.Absolute,30));right.RowStyles.Add(new RowStyle(SizeType.Absolute,130));right.RowStyles.Add(new RowStyle(SizeType.Absolute,30));right.RowStyles.Add(new RowStyle(SizeType.Percent,100));right.RowStyles.Add(new RowStyle(SizeType.Absolute,65));layout.Controls.Add(right,2,1);picture.Dock=DockStyle.Fill;picture.SizeMode=PictureBoxSizeMode.Zoom;right.Controls.Add(picture);right.Controls.Add(new Label{Text="영향 방향",Dock=DockStyle.Fill});
  var arrows=new TableLayoutPanel{Dock=DockStyle.Fill,ColumnCount=3,RowCount=3};for(int j=0;j<3;j++){arrows.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,33.33f));arrows.RowStyles.Add(new RowStyle(SizeType.Percent,33.33f));}string[] symbols={"↖","↑","↗","←","→","↙","↓","↘"};for(int j=0;j<8;j++){var cb=new CheckBox{Text=symbols[j],Dock=DockStyle.Fill,Font=new Font("Segoe UI Symbol",16)};dirs.Add(Data.Directions[j],cb);arrows.Controls.Add(cb,Data.DX[j]+1,Data.DY[j]+1);cb.CheckedChanged+=(s,e)=>Changed();}right.Controls.Add(arrows);right.Controls.Add(new Label{Text="영향 범위 · 6 × 5",Dock=DockStyle.Fill});board.Dock=DockStyle.Fill;right.Controls.Add(board);status.Dock=DockStyle.Fill;status.Text="설명·방향 데이터 편집\n전투 효과 실행 코드는 별도입니다.";right.Controls.Add(status);
  list.SelectedIndexChanged+=(s,e)=>{if(loading)return;var next=list.SelectedItem as Card;if(next==current)return;if(!Commit()){loading=true;list.SelectedItem=current;loading=false;return;}LoadCard(next);};FormClosing+=(s,e)=>{if(!CanLeave())e.Cancel=true;};RefreshList(null);
 }
 string Unique(string id){string s=id;int i=2;while(catalog.cards.Any(c=>c.id==s))s=id+i++;return s;}
 ComboBox Combo(string[] values){var c=new ComboBox{DropDownStyle=ComboBoxStyle.DropDownList};c.Items.AddRange(values);return c;}
 void AddButton(Control p,string name,Action a){var b=new Button{Text=name,AutoSize=true,Height=34};b.Click+=(s,e)=>{try{a();}catch(Exception ex){MessageBox.Show(ex.Message,"작업 실패");}};p.Controls.Add(b);}
 void Field(TableLayoutPanel p,string key,string label,Control c){int row=p.RowCount++;p.RowStyles.Add(new RowStyle(SizeType.Absolute,key=="description"?112:39));p.Controls.Add(new Label{Text=label,Dock=DockStyle.Fill,TextAlign=ContentAlignment.MiddleLeft},0,row);c.Dock=DockStyle.Fill;p.Controls.Add(c,1,row);fields[key]=c;if(c is CheckBox)((CheckBox)c).CheckedChanged+=(s,e)=>Changed();else if(c is NumericUpDown)((NumericUpDown)c).ValueChanged+=(s,e)=>Changed();else c.TextChanged+=(s,e)=>Changed();}
 void Changed(){if(loading)return;dirty=true;UpdatePreview();}
 void RefreshList(Card selected){loading=true;list.Items.Clear();foreach(var c in catalog.cards.Where(c=>(c.name+" "+c.id).IndexOf(search.Text,StringComparison.OrdinalIgnoreCase)>=0))list.Items.Add(c);list.SelectedItem=selected;if(list.SelectedIndex<0&&list.Items.Count>0)list.SelectedIndex=0;loading=false;LoadCard(list.SelectedItem as Card);}
 void LoadCard(Card c){current=c;loading=true;foreach(var kv in fields){kv.Value.Enabled=c!=null;if(c==null)continue;var value=typeof(Card).GetProperty(kv.Key).GetValue(c,null);if(kv.Value is CheckBox)((CheckBox)kv.Value).Checked=(bool)value;else if(kv.Value is NumericUpDown)((NumericUpDown)kv.Value).Value=Convert.ToDecimal(value);else kv.Value.Text=Convert.ToString(value).Replace("\r\n","\n").Replace("\n","\r\n");}foreach(var kv in dirs){kv.Value.Enabled=c!=null;kv.Value.Checked=c!=null&&c.directions.Contains(kv.Key);}loading=false;UpdatePreview();}
 Card Read(){if(current==null)return null;var c=Data.Json.Deserialize<Card>(Data.Json.Serialize(current));foreach(var kv in fields){object v=kv.Value.Text;if(kv.Value is CheckBox)v=((CheckBox)kv.Value).Checked;else if(kv.Value is NumericUpDown)v=(int)((NumericUpDown)kv.Value).Value;typeof(Card).GetProperty(kv.Key).SetValue(c,v,null);}c.directions=dirs.Where(k=>k.Value.Checked).Select(k=>k.Key).ToArray();return c;}
 bool Commit(){if(current==null)return true;try{var c=Read();var index=catalog.cards.IndexOf(current);var test=new Catalog{schema_version=1,cards=catalog.cards.Select(x=>x==current?c:x).ToList()};Data.Validate(test);catalog.cards[index]=c;int li=list.Items.IndexOf(current);current=c;if(li>=0){loading=true;list.Items[li]=c;loading=false;}return true;}catch(Exception e){MessageBox.Show(e.Message,"입력 확인");return false;}}
 void UpdatePreview(){board.Card=Read();board.Invalidate();if(board.Card==null)return;picture.BackColor=board.Card.dark?Color.FromArgb(35,38,38):Color.White;var old=picture.Image;using(var m=new MemoryStream(Data.Bytes("icon."+board.Card.icon))){var bitmap=new Bitmap(m);for(int y=0;y<bitmap.Height;y++)for(int x=0;x<bitmap.Width;x++){var p=bitmap.GetPixel(x,y);bitmap.SetPixel(x,y,Color.FromArgb(p.A,board.Card.dark?Color.White:Color.Black));}picture.Image=bitmap;}if(old!=null)old.Dispose();status.Font=new Font("Malgun Gothic",9);status.Text="-1: 미정 · 0: 무료 / 0점\n효과 실행 코드: 별도 연결";}
 bool SaveJson(){if(!Commit())return false;using(var d=new SaveFileDialog{Filter="카드 JSON|*.json",FileName="카드목록.json"}){if(d.ShowDialog()!=DialogResult.OK)return false;Data.Save(d.FileName,Data.Json.Serialize(catalog));dirty=false;return true;}}
 bool CanLeave(){if(!dirty)return true;var r=MessageBox.Show("변경한 카드 목록을 저장할까요?","저장하지 않은 변경",MessageBoxButtons.YesNoCancel);return r==DialogResult.No||(r==DialogResult.Yes&&SaveJson());}
 public void Smoke(string folder){Show();Application.DoEvents();fields["name"].Text="검증 카드";dirs["up_right"].Checked=true;if(!Commit()||current.name!="검증 카드"||!current.directions.Contains("up_right"))throw new Exception("UI edit failed");foreach(var size in new[]{new Size(1380,860),new Size(1120,740)}){Size=size;Application.DoEvents();using(var bmp=new Bitmap(Width,Height)){DrawToBitmap(bmp,new Rectangle(Point.Empty,Size));bmp.Save(Path.Combine(folder,"editor_"+Width+".png"));}}dirty=false;Close();}
}
static class Program {
 [STAThread] static int Main(string[] args){try{Application.EnableVisualStyles();Application.SetCompatibleTextRenderingDefault(false);var c=Data.Parse(Data.Text("default_cards.json"));if(args.Length>1&&args[0]=="--deliver"){Directory.CreateDirectory(args[1]);Data.Html(c,Path.Combine(args[1],"카드_이름_효과_정리.html"));Data.Save(Path.Combine(args[1],"카드목록.json"),Data.Json.Serialize(c));Data.Export(c,args[1]);File.WriteAllText(Path.Combine(args[1],"사용안내.txt"),Data.Text("README.txt"),Encoding.UTF8);return 0;}if(args.Length>1&&args[0]=="--test"){Directory.CreateDirectory(args[1]);Data.Parse(Data.Json.Serialize(c));var bad=Data.Parse(Data.Json.Serialize(c));bad.cards[1].id=bad.cards[0].id;bool rejected=false;try{Data.Validate(bad);}catch{rejected=true;}if(!rejected)throw new Exception("Duplicate accepted");c.cards[0].directions=Data.Directions;c.cards[0].description="한글 \"인용\"\n줄바꿈 <script>";var root=Data.Export(c,args[1]);Data.Html(c,Path.Combine(args[1],"catalog.html"));new Editor(c).Smoke(args[1]);File.WriteAllText(Path.Combine(args[1],"PASS.txt"),"JSON roundtrip, duplicate rejection, export, HTML, UI edit and two viewport captures PASS\n"+root);return 0;}Application.Run(new Editor(c));return 0;}catch(Exception ex){if(args.Length>1)File.WriteAllText(Path.Combine(args[1],"ERROR.txt"),ex.ToString());else MessageBox.Show(ex.Message,"LYNCO 오류");return 1;}}
}
