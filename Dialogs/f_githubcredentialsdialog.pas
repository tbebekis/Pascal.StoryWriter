unit f_GithubCredentialsDialog;

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

  { TGithubCredentialsDialog }

  TGithubCredentialsDialog = class(TForm)
    btnCancel: TButton;
    btnOK: TButton;
    edtUsername: TEdit;
    edtToken: TEdit;
    Label2: TLabel;
    Label3: TLabel;
    Memo1: TMemo;
  protected
    procedure AnyClick(Sender: TObject);
    procedure FormInitialize();
    procedure ItemToControls();
    procedure ControlsToItem();
    procedure DoShow; override;
  public
    class function ShowDialog(var UserName: string; var Token: string): Boolean;
  end;



implementation

{$R *.lfm}


{ TGithubCredentialsDialog }

class function TGithubCredentialsDialog.ShowDialog(var UserName: string; var Token: string): Boolean;
var
  Dlg: TGithubCredentialsDialog;
begin
  Result := False;

  Dlg := TGithubCredentialsDialog.Create(nil);
  try

    Dlg.edtUserName.Text := UserName;
    Dlg.edtToken.Text := Token;
    Result := Dlg.ShowModal() = mrOk;
    if Result then
    begin
      UserName:= Trim(Dlg.edtUserName.Text);
      Token:= Trim(Dlg.edtToken.Text);
    end;
  finally
    Dlg.Free;
  end;

end;

procedure TGithubCredentialsDialog.DoShow;
begin
  inherited DoShow;
  FormInitialize();
end;

procedure TGithubCredentialsDialog.FormInitialize();
begin
  btnOK.Default := True;
  btnCancel.Cancel := True;
  btnOK.OnClick := AnyClick;
  edtUserName.SetFocus();
  ItemToControls();
end;

procedure TGithubCredentialsDialog.ItemToControls();
begin
end;

procedure TGithubCredentialsDialog.ControlsToItem();
begin
  if (Trim(edtUserName.Text) <> '') and (Trim(edtToken.Text) <> '') then
    Self.ModalResult := mrOK;
end;

procedure TGithubCredentialsDialog.AnyClick(Sender: TObject);
begin
  if btnOK = Sender then
    ControlsToItem();
end;


end.

