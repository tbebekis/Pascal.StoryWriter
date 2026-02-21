unit f_ExportDialog;

{$mode DELPHI}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls
  ,o_ExportOptions
  ;

type

  { TExportDialog }

  TExportDialog = class(TForm)
    btnCancel: TButton;
    btnOK: TButton;
    chGreek: TCheckBox;
    chODT: TCheckBox;
    chSceneBullet: TCheckBox;
    chSceneNumber: TCheckBox;
    chSceneWord: TCheckBox;
    chSceneTitle: TCheckBox;
    chSingleComponentText: TCheckBox;
    chPreEditScenes: TCheckBox;
    chPreEditChapters: TCheckBox;
    chEnglish: TCheckBox;
    chChapterBullet: TCheckBox;
    chChapterNumber: TCheckBox;
    chChapterWord: TCheckBox;
    chChapterTitle: TCheckBox;
    chText: TCheckBox;
    chSynopsis: TCheckBox;
    chTXT: TCheckBox;
    gboLanguage: TGroupBox;
    gboChapterTitles: TGroupBox;
    gboText: TGroupBox;
    gboFormat: TGroupBox;
    gboSceneTitles: TGroupBox;
    gboSpecialExports: TGroupBox;
    Label1: TLabel;
  protected
    Options : TExportOptions;
    procedure AnyClick(Sender: TObject);
    procedure FormInitialize();
    procedure ItemToControls();
    procedure ControlsToItem();
    procedure DoShow; override;
  public
    class function ShowDialog(AOptions: TExportOptions): Boolean;
  end;

var
  ExportDialog: TExportDialog;

implementation

{$R *.lfm}

{ TExportDialog }

class function TExportDialog.ShowDialog(AOptions: TExportOptions): Boolean;
var
  Dlg: TExportDialog;
begin
  Result := False;

  Dlg := TExportDialog.Create(nil);
  try
    Dlg.Options := AOptions;
    Result := Dlg.ShowModal() = mrOk;
  finally
    Dlg.Free;
  end;

end;

procedure TExportDialog.DoShow;
begin
  inherited DoShow;
  FormInitialize();
end;

procedure TExportDialog.FormInitialize();
begin
  btnOK.Default := True;
  btnCancel.Cancel := True;
  btnOK.OnClick := AnyClick;

  ItemToControls();
end;

procedure TExportDialog.ItemToControls();
begin
  chGreek.Checked   := elGreek in Options.Language;
  chEnglish.Checked := elEnglish in Options.Language;

  chText.Checked     := esText in Options.Source;
  chSynopsis.Checked := esSynopsis in Options.Source;

  chTXT.Checked := efTXT in Options.Format;
  chODT.Checked := efODT in Options.Format;

  chChapterBullet.Checked := etoBullet in Options.ChapterTitle;
  chChapterNumber.Checked := etoNumber in Options.ChapterTitle;
  chChapterWord.Checked   := etoWord   in Options.ChapterTitle;
  chChapterTitle.Checked  := etoTitle  in Options.ChapterTitle;

  chSceneBullet.Checked := etoBullet in Options.SceneTitle;
  chSceneNumber.Checked := etoNumber in Options.SceneTitle;
  chSceneWord.Checked   := etoWord   in Options.SceneTitle;
  chSceneTitle.Checked  := etoTitle  in Options.SceneTitle;

  chSingleComponentText.Checked := Options.SingleComponentText;
  chPreEditScenes.Checked       := Options.PreEditScenes;
  chPreEditChapters.Checked     := Options.PreEditChapters;
end;

procedure TExportDialog.ControlsToItem();
var
  L: TExportLanguages;
  S: TExportSources;
  F: TExportFormats;
  CT: TExportTitleOptions;
  ST: TExportTitleOptions;
begin
  Options.Clear;

  L := [];
  if chGreek.Checked then
    Include(L, elGreek);
  if chEnglish.Checked then
    Include(L, elEnglish);
  Options.Language := L;

  S := [];
  if chText.Checked then
    Include(S, esText);
  if chSynopsis.Checked then
    Include(S, esSynopsis);
  Options.Source := S;

  F := [];
  if chTXT.Checked then
    Include(F, efTXT);
  if chODT.Checked then
    Include(F, efODT);
  Options.Format := F;

  CT := [];
  if chChapterBullet.Checked then
    Include(CT, etoBullet);
  if chChapterNumber.Checked then
    Include(CT, etoNumber);
  if chChapterWord.Checked then
    Include(CT, etoWord);
  if chChapterTitle.Checked then
    Include(CT, etoTitle);
  Options.ChapterTitle := CT;

  ST := [];
  if chSceneBullet.Checked then
    Include(ST, etoBullet);
  if chSceneNumber.Checked then
    Include(ST, etoNumber);
  if chSceneWord.Checked then
    Include(ST, etoWord);
  if chSceneTitle.Checked then
    Include(ST, etoTitle);
  Options.SceneTitle := ST;

  Options.SingleComponentText := chSingleComponentText.Checked;
  Options.PreEditScenes       := chPreEditScenes.Checked;
  Options.PreEditChapters     := chPreEditChapters.Checked;
end;

procedure TExportDialog.AnyClick(Sender: TObject);
begin
  if btnOK = Sender then
    ControlsToItem();
end;





end.

