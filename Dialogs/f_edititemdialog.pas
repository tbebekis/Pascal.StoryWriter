unit f_EditItemDialog;

{$MODE DELPHI}{$H+}

interface

uses
  Classes
  , SysUtils
  , Forms
  , Controls
  , Graphics
  , Dialogs
  , StdCtrls

  ;



type

  { TEditItemDialog }

  TEditItemDialog = class(TForm)
    btnCancel: TButton;
    btnOK: TButton;
    edtParentName: TEdit;
    edtName: TEdit;
    Label1: TLabel;
    Label2: TLabel;
  private
  protected
    procedure AnyClick(Sender: TObject);
    procedure FormInitialize();
    procedure ItemToControls();
    procedure ControlsToItem();
    procedure DoShow; override;
  public
    class function ShowDialog(const Title: string; const ParentName: string; var ResultName: string): Boolean;
  end;



implementation

{$R *.lfm}

uses
  o_App
  ;

{ TEditItemDialog }

class function TEditItemDialog.ShowDialog(const Title: string; const ParentName: string; var ResultName: string): Boolean;
var
  Dlg: TEditItemDialog;
begin
  Result := False;

  Dlg := TEditItemDialog.Create(nil);
  try
    Dlg.Caption := Title;
    Dlg.edtParentName.Text := ParentName;
    Dlg.edtName.Text := ResultName;
    Result := Dlg.ShowModal() = mrOk;
    if Result then
    begin
      ResultName := Trim(Dlg.edtName.Text);
    end;
  finally
    Dlg.Free;
  end;

end;

procedure TEditItemDialog.DoShow;
begin
  inherited DoShow;
  FormInitialize();
end;

procedure TEditItemDialog.FormInitialize();
begin
  btnOK.Default := True;
  btnCancel.Cancel := True;
  btnOK.OnClick := AnyClick;
  edtName.SetFocus();
  ItemToControls();
end;

procedure TEditItemDialog.ItemToControls();
begin
end;

procedure TEditItemDialog.ControlsToItem();
begin
  if not App.IsValidFileName(Trim(edtName.Text), True) then
    Exit;

  Self.ModalResult := mrOK;
end;

procedure TEditItemDialog.AnyClick(Sender: TObject);
begin
  if btnOK = Sender then
    ControlsToItem();
end;


end.

