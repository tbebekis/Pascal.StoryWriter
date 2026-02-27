unit f_AppSettingsDialog;

{$mode DELPHI}{$H+}

interface

uses
  Classes
  , SysUtils
  , Forms
  , Controls
  , Graphics
  , Dialogs
  , StdCtrls
  , o_AppSettings
  ;

type

  { TAppSettingsDialog }
  TAppSettingsDialog = class(TForm)
    btnCancel: TButton;
    btnOK: TButton;
    chAutoSave: TCheckBox;
    chGutterVisible: TCheckBox;
    chLoadLast: TCheckBox;
    chEnglishVisible: TCheckBox;
    cboFontFamily: TComboBox;
    chMinimapTooltipVisible: TCheckBox;
    chMinimapVisible: TCheckBox;
    chRulerVisible: TCheckBox;
    chShowCurLine: TCheckBox;
    chUseHighlighters: TCheckBox;
    edtAutoSaveSecondsInterval: TEdit;
    edtFontSize: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
  private
    Settings: TAppSettings;
  protected
    procedure AnyClick(Sender: TObject);
    procedure FormInitialize();
    procedure ItemToControls();
    procedure ControlsToItem();
    procedure DoShow; override;
  public
    class function ShowDialog(): Boolean;

  end;



implementation

{$R *.lfm}

uses
  o_App
  ;

{ TAppSettingsDialog }

class function TAppSettingsDialog.ShowDialog(): Boolean;
var
  Dlg: TAppSettingsDialog;
begin
  Result := False;

  Dlg := TAppSettingsDialog.Create(nil);
  try
    Result := Dlg.ShowModal() = mrOk;
  finally
    Dlg.Free;
  end;

end;

procedure TAppSettingsDialog.DoShow;
begin
  inherited DoShow;
  FormInitialize();
end;

procedure TAppSettingsDialog.FormInitialize();
begin
  btnOK.Default := True;
  btnCancel.Cancel := True;
  btnOK.OnClick := AnyClick;

  cboFontFamily.Items.Assign(Screen.Fonts);
  cboFontFamily.Sorted := True;

  Settings := App.Settings;

  ItemToControls();
end;

procedure TAppSettingsDialog.ItemToControls();
var
  Index: Integer;
begin
  chAutoSave.Checked := Settings.AutoSave;
  edtAutoSaveSecondsInterval.Text := IntToStr(Settings.AutoSaveSecondsInterval);

  chLoadLast.Checked := Settings.LoadLastProjectOnStartup;
  chEnglishVisible.Checked := Settings.EnglishVisible;

  chUseHighlighters.Checked := Settings.UseHighlighters;
  chGutterVisible.Checked := Settings.GutterVisible;
  chRulerVisible.Checked := Settings.RulerVisible;
  chShowCurLine.Checked := Settings.ShowCurLine;
  chMinimapVisible.Checked := Settings.MinimapVisible;
  chMinimapTooltipVisible.Checked := Settings.MinimapTooltipVisible;

  Index := cboFontFamily.Items.IndexOf(Settings.FontName);
  if Index <> -1 then
    cboFontFamily.ItemIndex := Index;

  edtFontSize.Text := IntToStr(Settings.FontSize);
end;

procedure TAppSettingsDialog.ControlsToItem();
begin
  Settings.AutoSave := chAutoSave.Checked;
  Settings.AutoSaveSecondsInterval := App.GetEditBoxIntValue(edtAutoSaveSecondsInterval, Settings.AutoSaveSecondsInterval);

  Settings.LoadLastProjectOnStartup := chLoadLast.Checked;
  Settings.EnglishVisible := chEnglishVisible.Checked;

  Settings.UseHighlighters := chUseHighlighters.Checked;
  Settings.GutterVisible := chGutterVisible.Checked;
  Settings.RulerVisible := chRulerVisible.Checked;
  Settings.ShowCurLine := chShowCurLine.Checked;
  Settings.MinimapVisible := chMinimapVisible.Checked;
  Settings.MinimapTooltipVisible := chMinimapTooltipVisible.Checked;

  if cboFontFamily.ItemIndex <> -1 then;
    Settings.FontName := cboFontFamily.Items[cboFontFamily.ItemIndex];

  Settings.FontSize := App.GetEditBoxIntValue(edtFontSize, Settings.FontSize);

  Settings.Save();
  Self.ModalResult := mrOK;
end;

procedure TAppSettingsDialog.AnyClick(Sender: TObject);
begin
  if btnOK = Sender then
    ControlsToItem();
end;



end.

