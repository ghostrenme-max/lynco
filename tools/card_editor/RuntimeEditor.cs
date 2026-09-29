using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using System.Drawing;
using System.Windows.Forms;

public class BattleRules {
 public int starting_cubes {get;set;} public int turn_cubes {get;set;} public int energy {get;set;} public int max_turns {get;set;}
 public int cube_weight {get;set;} public int score_weight {get;set;} public int recover_delay {get;set;} public int recover_fee {get;set;} public int final_invested_percent {get;set;}
 public string end_mode {get;set;}
 public BattleRules(){starting_cubes=6;turn_cubes=1;energy=3;max_turns=8;cube_weight=3;score_weight=1;recover_delay=1;recover_fee=1;final_invested_percent=0;end_mode="either";}
}
public class CodeItem {
 public string Code,Label;
 public CodeItem(string code,string label){Code=code;Label=label;}
 public override string ToString(){return Label;}
}
static partial class Data {
 public static readonly string[] Effects={"none","score","cubes","energy","draw"};
 public static void Upgrade(Catalog c){
  if(c==null)return;
  if(c.schema_version==1){
   var bundled=Json.Deserialize<Catalog>(Text("default_cards.json"));
   foreach(var x in c.cards??new List<Card>()){
    var template=bundled.cards.FirstOrDefault(b=>b.id==x.id);
    x.base_effect=template==null?"none":template.base_effect;x.base_value=template==null?0:template.base_value;
    x.link_effect=template==null?"none":template.link_effect;x.link_value=template==null?0:template.link_value;
    x.link_condition="any";x.link_trigger="any";x.investment_cost=template==null?0:template.investment_cost;x.invest_bonus=template==null?0:template.invest_bonus;
    x.deck_starter=template==null?0:template.deck_starter;x.deck_remnant=template==null?0:template.deck_remnant;
   }
   c.rules=new BattleRules();c.schema_version=2;
  }
 }
 public static void ValidateRuntime(Catalog c){
  if(c.rules==null)throw new Exception("전투 규칙이 없습니다.");
  var r=c.rules;
  if(r.starting_cubes<0||r.starting_cubes>100||r.turn_cubes<0||r.turn_cubes>20||r.energy<1||r.energy>10||r.max_turns<1||r.max_turns>30||r.cube_weight<1||r.cube_weight>20||r.score_weight<0||r.score_weight>20||r.recover_delay<1||r.recover_delay>10||r.recover_fee<0||r.recover_fee>5||r.final_invested_percent<0||r.final_invested_percent>100||r.end_mode!="either")throw new Exception("전투 규칙 범위를 확인하세요.");
  foreach(var x in c.cards){
   if(x.face!="front")continue;
   if(!Effects.Contains(x.base_effect)||!Effects.Contains(x.link_effect)||!new[]{"any","ally","enemy"}.Contains(x.link_condition)||!new[]{"on_place","on_invest","turn_start","any"}.Contains(x.link_trigger))throw new Exception(x.id+": 실행 효과/연결 조건을 선택하세요.");
   if(x.cost<0||x.cost>10||x.base_value<0||x.base_value>20||x.link_value<0||x.link_value>20||x.investment_cost<0||x.investment_cost>5||x.invest_bonus<0||x.invest_bonus>20||x.deck_starter<0||x.deck_starter>30||x.deck_remnant<0||x.deck_remnant>30)throw new Exception(x.id+": 전투 수치 범위 오류");
  }
  int a=c.cards.Where(x=>x.face=="front").Sum(x=>x.deck_starter),b=c.cards.Where(x=>x.face=="front").Sum(x=>x.deck_remnant);
  if(a<5||a>60||b<5||b>60)throw new Exception("기본 덱과 상대 덱은 각각 5~60장이어야 합니다.");
 }
 public static void Backup(string path){if(File.Exists(path)){var backup=path+".before-linked-"+DateTime.Now.ToString("yyyyMMdd_HHmmss_fff")+".bak";File.Copy(path,backup,false);}}
 public static void ApplyGame(Catalog c,string project){
  Validate(c);
  project=Path.GetFullPath(project);
  if(!File.Exists(Path.Combine(project,"project.godot"))||!File.Exists(Path.Combine(project,"scripts","linked_rules.gd")))throw new Exception("연결 규칙을 지원하는 LYNCO 프로젝트 폴더를 선택하세요.");
  string folder=Path.Combine(project,"data"),path=Path.Combine(folder,"battle_cards.json");Directory.CreateDirectory(folder);
  Backup(path);Save(path,Json.Serialize(c));
 }
}
partial class Editor {
 Dictionary<string,NumericUpDown> ruleFields=new Dictionary<string,NumericUpDown>();
 Label runtimeSummary;
 ComboBox RuntimeCombo(string[] codes,string[] labels){var cb=new ComboBox{DropDownStyle=ComboBoxStyle.DropDownList,Tag="runtime-code"};for(int i=0;i<codes.Length;i++)cb.Items.Add(new CodeItem(codes[i],labels[i]));return cb;}

 void RuntimeTabs(TableLayoutPanel layout,TableLayoutPanel form){
  layout.Controls.Remove(form);var tabs=new TabControl{Dock=DockStyle.Fill};layout.Controls.Add(tabs,1,1);
  var basic=new TabPage("기본 정보");basic.Controls.Add(form);tabs.TabPages.Add(basic);
  var effectsPage=new TabPage("실제 효과 · 조건");tabs.TabPages.Add(effectsPage);
  var f=new TableLayoutPanel{Dock=DockStyle.Fill,AutoScroll=true,ColumnCount=2,Padding=new Padding(4,10,18,0)};f.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute,125));f.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));effectsPage.Controls.Add(f);
  string[] labels={"없음","성과 획득","큐브 획득","행동력 획득","카드 드로우"};
  Field(f,"base_effect","기본 효과",RuntimeCombo(Data.Effects,labels));Field(f,"base_value","기본 수치",new NumericUpDown{Maximum=20});
  Field(f,"link_effect","연결 효과",RuntimeCombo(Data.Effects,labels));Field(f,"link_value","연결 수치",new NumericUpDown{Maximum=20});
  Field(f,"link_condition","연결 대상",RuntimeCombo(new[]{"any","ally","enemy"},new[]{"양측 카드","같은 소유자","다른 소유자"}));
  Field(f,"link_trigger","발동 시점",RuntimeCombo(new[]{"on_place","on_invest","turn_start","any"},new[]{"대상 카드 배치","출발 카드 투자","대상 주인의 턴 시작","배치 + 투자 + 턴 시작"}));
  Field(f,"requires_investment","발동 조건",new CheckBox{Text="출발 카드에 투자 필수"});
  Field(f,"investment_cost","투자 큐브",new NumericUpDown{Maximum=5});Field(f,"invest_bonus","투자 추가 수치",new NumericUpDown{Maximum=20});
  Field(f,"deck_starter","기본 덱 장수",new NumericUpDown{Maximum=30});Field(f,"deck_remnant","상대 덱 장수",new NumericUpDown{Maximum=30});
  var note=new Label{Text="방향은 출발 카드 기준입니다. 효과는 연결 대상의 주인에게 지급됩니다.\n한 이벤트에서 각 연결을 한 번 처리합니다. 뒷면 효과는 아직 적용하지 않습니다.",AutoSize=true,MaximumSize=new Size(440,0),Margin=new Padding(4,14,4,12)};f.Controls.Add(note,0,f.RowCount++);f.SetColumnSpan(note,2);
  var rp=new TabPage("전투 규칙 · 임시값");tabs.TabPages.Add(rp);
  var r=new TableLayoutPanel{Dock=DockStyle.Fill,AutoScroll=true,ColumnCount=2,Padding=new Padding(8)};r.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute,180));r.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));rp.Controls.Add(r);
  RuleField(r,"starting_cubes","시작 큐브",0,100);RuleField(r,"turn_cubes","턴당 새 큐브",0,20);RuleField(r,"energy","턴 시작 행동력",1,10);RuleField(r,"max_turns","최대 턴 수",1,30);RuleField(r,"cube_weight","큐브 점수 배수",1,20);RuleField(r,"score_weight","성과 점수 배수",0,20);RuleField(r,"recover_delay","회수 대기 턴 수",1,10);RuleField(r,"recover_fee","회수 비용 (큐브)",0,5);RuleField(r,"final_invested_percent","투자금 인정 (%)",0,100);
  runtimeSummary=new Label{AutoSize=true,MaximumSize=new Size(440,0),Text="최대 턴 완료 또는 30칸이 차면 종료합니다.\n판정 = (보유 + 인정된 투자금) × 큐브 배수 + 성과 × 성과 배수\n회수 비용은 투자금 한도에서 차감합니다. 같은 턴 재투자 금지.\n게임 적용 후 게임을 다시 실행하세요.",Margin=new Padding(4,14,4,12)};r.Controls.Add(runtimeSummary,0,r.RowCount++);r.SetColumnSpan(runtimeSummary,2);
  RefreshRules();
 }
 void RuleField(TableLayoutPanel p,string key,string title,int min,int max){int row=p.RowCount++;p.RowStyles.Add(new RowStyle(SizeType.Absolute,42));p.Controls.Add(new Label{Text=title,Dock=DockStyle.Fill,TextAlign=ContentAlignment.MiddleLeft},0,row);var field=new NumericUpDown{Minimum=min,Maximum=max,Dock=DockStyle.Fill};ruleFields[key]=field;p.Controls.Add(field,1,row);field.ValueChanged+=(s,e)=>{if(loading)return;typeof(BattleRules).GetProperty(key).SetValue(catalog.rules,(int)field.Value,null);dirty=true;};}
 void RefreshRules(){bool before=loading;loading=true;foreach(var pair in ruleFields)pair.Value.Value=Convert.ToDecimal(typeof(BattleRules).GetProperty(pair.Key).GetValue(catalog.rules,null));loading=before;}
 void ApplyGame(){
  if(!Commit())return;
  string setting=Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"lynco-project.txt"),project=File.Exists(setting)?File.ReadAllText(setting).Trim():"D:\\Lynco";
  using(var d=new FolderBrowserDialog{Description="실제 LYNCO 게임 프로젝트 폴더 (project.godot)",SelectedPath=Directory.Exists(project)?project:""}){
   if(d.ShowDialog()!=DialogResult.OK)return;project=d.SelectedPath;
  }
  Data.ApplyGame(catalog,project);
  string source=Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"카드목록.json");Data.Backup(source);Data.Save(source,Data.Json.Serialize(catalog));Data.Save(setting,project);dirty=false;
  MessageBox.Show("게임 카드·규칙 적용 완료.\n실행 중인 게임을 다시 시작하면 새 설정을 읽습니다.\n기존 JSON은 .bak 파일로 보존했습니다.","게임 적용");
 }
 public void RuntimeSmoke(string folder){
  var cb=(ComboBox)fields["base_effect"];cb.SelectedItem=cb.Items.Cast<CodeItem>().First(x=>x.Code=="cubes");
  ((NumericUpDown)fields["base_value"]).Value=4;((NumericUpDown)fields["cost"]).Value=2;
  cb=(ComboBox)fields["link_condition"];cb.SelectedItem=cb.Items.Cast<CodeItem>().First(x=>x.Code=="enemy");
  cb=(ComboBox)fields["link_trigger"];cb.SelectedItem=cb.Items.Cast<CodeItem>().First(x=>x.Code=="on_invest");
  cb=(ComboBox)fields["link_effect"];cb.SelectedItem=cb.Items.Cast<CodeItem>().First(x=>x.Code=="score");
  ((NumericUpDown)fields["link_value"]).Value=3;((NumericUpDown)fields["investment_cost"]).Value=2;
  ((NumericUpDown)fields["invest_bonus"]).Value=2;((CheckBox)fields["requires_investment"]).Checked=true;
  ruleFields["starting_cubes"].Value=9;ruleFields["max_turns"].Value=6;
  foreach(string key in new[]{"base_effect","link_effect","link_condition","link_trigger"})if(String.IsNullOrWhiteSpace(fields[key].Text))throw new Exception("Empty selector label: "+key);
  if(!Commit())throw new Exception("Runtime editor commit failed");
  var clone=Data.Parse(Data.Json.Serialize(catalog));
  if(clone.cards[0].base_effect!="cubes"||clone.cards[0].base_value!=4||clone.cards[0].link_condition!="enemy"||clone.rules.starting_cubes!=9)throw new Exception("Runtime edit persistence failed");
  Data.Save(Path.Combine(folder,"runtime_ui_saved.json"),Data.Json.Serialize(catalog));
  var tabs=(TabControl)fields["base_effect"].Parent.Parent.Parent;
  foreach(int index in new[]{1,2}){tabs.SelectedIndex=index;Refresh();Application.DoEvents();using(var bmp=new Bitmap(Width,Height)){DrawToBitmap(bmp,new Rectangle(Point.Empty,Size));bmp.Save(Path.Combine(folder,"runtime_tab_"+index+".png"));}}
 }

}
