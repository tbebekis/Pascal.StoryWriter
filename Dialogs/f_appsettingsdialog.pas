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
    chLoadLast: TCheckBox;
    chAutoSave: TCheckBox;
    chEnglishVisible: TCheckBox;
    cboFontFamily: TComboBox;
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
(*
Καλές επιλογές που ήδη έχεις (για editor/markdown)
DejaVu Sans Mono (σίγουρη, καθαρή, παντού)
Liberation Mono (καλό fallback, ωραίο spacing)
Noto Sans Mono (καθαρό, σύγχρονο)
Ubuntu Mono (ωραίο για πολύωρη χρήση)
Nimbus Mono PS (OK, πιο “παλιό” look)
Και αν θες non-monospace για UI:
DejaVu Sans
Ubuntu
Open Sans (αν το έχεις πλήρες)
*)

  chLoadLast.Checked := Settings.LoadLastProjectOnStartup;
  chAutoSave.Checked := Settings.AutoSave;
  chEnglishVisible.Checked := Settings.EnglishVisible;

  edtAutoSaveSecondsInterval.Text := IntToStr(Settings.AutoSaveSecondsInterval);

  Index := cboFontFamily.Items.IndexOf(Settings.FontFamily);
  if Index <> -1 then
    cboFontFamily.ItemIndex := Index;

  edtFontSize.Text := IntToStr(Settings.FontSize);

end;

procedure TAppSettingsDialog.ControlsToItem();
var
  N : Integer;
begin
  Settings.LoadLastProjectOnStartup := chLoadLast.Checked;
  Settings.AutoSave := chAutoSave.Checked;
  Settings.EnglishVisible := chEnglishVisible.Checked;

  if not TryStrToInt(Trim(edtAutoSaveSecondsInterval.Text), N) then
  begin
    App.ErrorBox('Wrong Auto-Save Seconds Interval');
    Exit;
  end;
  Settings.AutoSaveSecondsInterval := N;

  if cboFontFamily.ItemIndex <> -1 then;
    Settings.FontFamily := cboFontFamily.Items[cboFontFamily.ItemIndex];

  if not TryStrToInt(Trim(edtFontSize.Text), N) then
  begin
    App.ErrorBox('Wrong Font Size');
    Exit;
  end;
  Settings.FontSize := N;

  Settings.Save();
  Self.ModalResult := mrOK;
end;

procedure TAppSettingsDialog.AnyClick(Sender: TObject);
begin
  if btnOK = Sender then
    ControlsToItem();
end;



end.

