unit fr_Search;

{$MODE DELPHI}{$H+}

interface

uses
  Classes
  , SysUtils
  , Forms
  , Controls
  , Graphics
  , Dialogs
  , ExtCtrls
  , ComCtrls
  , StdCtrls
  , Contnrs
  , Menus
  , LCLType
  , LCLIntf
  , DB
  , DBCtrls
  , DBGrids
  , fr_FramePage
  , Tripous.MemTable
  , o_Entities
  , fr_TextEditor
  ;

type

  { TfrSearch }

  TfrSearch = class(TFramePage)
    edtSearch: TEdit;
    frText: TfrTextEditor;
    Label1: TLabel;
    pnlBottom: TPanel;
    pnlFilter: TPanel;
    pnlTitle: TPanel;
    pnlTop: TPanel;
    Splitter: TSplitter;
    ToolBar: TToolBar;
    tv: TTreeView;
  private
    LinkItems: TLinkItemList;

    // ● event handler
    procedure AnyClick(Sender: TObject);
    procedure AppOnProjectOpened(Sender: TObject);
    procedure AppOnProjectClosed(Sender: TObject);
    procedure AppOnItemChanged(Sender: TObject; Item: TBaseItem);
    procedure AppOnItemListChanged(Sender: TObject; ItemType: TItemType);
    procedure AppOnSearchTermIsSet(Sender: TObject; const Term: string);

    procedure edtSearchOnKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure tv_OnDoubleClick(Sender: TObject);
    procedure tv_OnSelectedNodeChanged(Sender: TObject; Node: TTreeNode);

    procedure GlobalSearchTermChanged();
    procedure ShowLinkItemPage();
    procedure ShowItemInListPage();

    procedure AddToQuickView();

    procedure SelectedNodeChanged();

    procedure ExpandAll();
    procedure CollapseAll();

    procedure ReLoad();
    procedure ClearAll();
  public
    procedure ControlInitialize; override;
    procedure ControlInitializeAfter(); override;
  end;

implementation

{$R *.lfm}

uses
   Tripous.Logs
  ,o_App
  ;

{ TfrSearch }


procedure TfrSearch.ControlInitialize;
begin
  inherited ControlInitialize;

  ParentTabPage.Caption := 'Search';

  ToolBar.ButtonHeight := 32;
  ToolBar.ButtonWidth := 32;

  tv.ReadOnly := True ;

  frText.ToolBarVisible := False;
  frText.Editor.ReadOnly := True;

  edtSearch.OnKeyDown := edtSearchOnKeyDown;
  tv.OnDblClick := tv_OnDoubleClick;
  tv.OnChange  := tv_OnSelectedNodeChanged;
end;

procedure TfrSearch.ControlInitializeAfter();
begin
  inherited ControlInitializeAfter();
  pnlTop.Height := (Self.ClientHeight - Splitter.Height) div 2;
end;

procedure TfrSearch.ReLoad();
var
  DocNo: Integer;
  BaseItem: TBaseItem;
  ParentNode, Node: TTreeNode;
  i: Integer;
  LI: TLinkItem;

  function ItemCaption(AItem: TLinkItem): string;
  begin
    Result := Format('%s - %s',
      [ItemTypeToString(AItem.ItemType), AItem.Item.DisplayTitleInProject]);
  end;

  function ChildCaption(AItem: TLinkItem): string;
  begin
    Result := Format('%s - (%d)',
      [LinkPlaceToString(AItem.Place), AItem.CharPos]);
  end;

begin
  Screen.Cursor := crHourGlass;
  Application.ProcessMessages;
  try
    ClearAll;

    Application.ProcessMessages;

    if Assigned(LinkItems) then
    begin
      tv.Items.BeginUpdate;
      try
        tv.Items.Clear;

        DocNo := 0;
        BaseItem := nil;
        ParentNode := nil;

        for i := 0 to LinkItems.Count - 1 do
        begin
          LI := LinkItems.Items[i];

          if LI.Item <> BaseItem then
          begin
            Inc(DocNo);
            BaseItem := LI.Item;
            ParentNode := tv.Items.Add(nil, ItemCaption(LI));
            ParentNode.Data := LI; // αντί Tag
          end;

          Node := tv.Items.AddChild(ParentNode, ChildCaption(LI));
          Node.Data := LI;
        end;

      finally
        tv.Items.EndUpdate;
      end;
    end;

    SelectedNodeChanged;
  finally
    Application.ProcessMessages;
    Screen.Cursor := crDefault;
  end;

end;

procedure TfrSearch.ClearAll();
begin
  tv.BeginUpdate();
  try
    tv.Items.Clear();
    pnlTitle.Caption := 'No selection';
    frText.Editor.Clear();
  finally
    tv.EndUpdate();
  end;
end;

procedure TfrSearch.GlobalSearchTermChanged();
var
  Msg: string;
  Term: string;
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  Term := Trim(edtSearch.Text);

  if Length(Term) > 2 then
  begin
    Msg := Format('Global search for term: "%s". Please wait...', [Term]);
    LogBox.AppendLine(Msg);

    //Wait.Show(Msg);

    Screen.Cursor := crHourGlass;
    Application.ProcessMessages;
    try
      LinkItems := App.CurrentProject.GlobalSearch(Term);

      ReLoad;

      // Select tab (αν είναι TPageControl)
      if (ParentTabPage.Parent is TPageControl) then
        TPageControl(ParentTabPage.Parent).ActivePage := ParentTabPage;
    finally
      Application.ProcessMessages;
      Screen.Cursor := crDefault;
      //Wait.ForceClose;
    end;

    Msg := Format(' Found items: %d', [LinkItems.Count]);
    LogBox.AppendLine(Msg);

    if LinkItems.Count = 0 then
    begin
      Msg := Format('No search results for "%s"', [Term]);
      LogBox.AppendLine(Msg);
      App.InfoBox(Msg);
    end;
  end
  else
  begin
    ClearAll;
  end;

end;

procedure TfrSearch.ShowLinkItemPage();
var
  Node: TTreeNode;
  LinkItem: TLinkItem;
  TabPage: TTabSheet;
  FramePage: TFramePage;
  Term: string;
  IsWholeWord: Boolean;
  MatchCase: Boolean;
begin
  Node := tv.Selected;
  if Assigned(Node) and Assigned(Node.Data) then
  begin
    LinkItem := TLinkItem(Node.Data);
    TabPage  := App.ShowLinkItemPage(LinkItem);
    if Assigned(TabPage) and (TabPage.Tag > 0)then
    begin
      FramePage := TFramePage(TabPage.Tag);

      Term := App.LastGlobalSearchTerm;
      IsWholeWord := App.LastGlobalSearchTermWholeWord;
      MatchCase := IsWholeWord;

      FramePage.HighlightAll(LinkItem, Term, IsWholeWord, MatchCase);
    end;
  end;
end;

procedure TfrSearch.ShowItemInListPage();
begin
  // TODO:  TfrSearch.ShowItemInListPage();
end;

procedure TfrSearch.SelectedNodeChanged();
var
  LinkItem: TLinkItem;
begin
  if Assigned(tv.Selected) and Assigned(tv.Selected.Data) then
  begin
    LinkItem := TLinkItem(tv.Selected.Data);
    App.UpdateLinkItemUi(LinkItem, pnlTitle, frText.Editor);
    Application.ProcessMessages();
  end;
end;

procedure TfrSearch.AnyClick(Sender: TObject);
begin

end;

procedure TfrSearch.AppOnProjectOpened(Sender: TObject);
begin

end;

procedure TfrSearch.AppOnProjectClosed(Sender: TObject);
begin

end;

procedure TfrSearch.AppOnItemChanged(Sender: TObject; Item: TBaseItem);
begin

end;

procedure TfrSearch.AppOnItemListChanged(Sender: TObject; ItemType: TItemType);
begin

end;

procedure TfrSearch.AppOnSearchTermIsSet(Sender: TObject; const Term: string);
begin

end;

procedure TfrSearch.edtSearchOnKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_RETURN then
     GlobalSearchTermChanged();
end;

procedure TfrSearch.tv_OnDoubleClick(Sender: TObject);
begin
  ShowLinkItemPage();
end;

procedure TfrSearch.tv_OnSelectedNodeChanged(Sender: TObject; Node: TTreeNode);
begin
  SelectedNodeChanged();
end;

procedure TfrSearch.AddToQuickView();
begin

end;


procedure TfrSearch.ExpandAll();
begin

end;

procedure TfrSearch.CollapseAll();
begin

end;






end.

