unit fr_StoryList;

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
  , ComCtrls, Menus
  , Tripous.Forms.FramePage
  , o_Entities
  ;

type

  { TfrStoryList }

  TfrStoryList = class(TFramePage)
    mnuAddStory: TMenuItem;
    mnuAddChapter: TMenuItem;
    mnuAddScene: TMenuItem;
    mnuAddItem: TPopupMenu;
    tvImages: TImageList;
    pnlTop: TPanel;
    pnlBottom: TPanel;
    Panel3: TPanel;
    Splitter: TSplitter;
    Splitter2: TSplitter;
    ToolBar: TToolBar;
    tv: TTreeView;
  private
    btnAddItem : TToolButton;
    btnEditItem : TToolButton;
    btnDeleteItem : TToolButton;
    btnEditText: TToolButton;
    btnExportStory: TToolButton;
    btnChangeParent: TToolButton;
    btnCollapseAll: TToolButton;
    btnExpandAll: TToolButton;
    btnUp: TToolButton;
    btnDown: TToolButton;

    // ● event handler
    procedure AnyClick(Sender: TObject);
    procedure AppOnProjectOpened(Sender: TObject);
    procedure AppOnProjectClosed(Sender: TObject);
    procedure AppOnProjectMetricsChanged(Sender: TObject);

    procedure TreeViewDblClick(Sender: TObject);
    procedure TreeViewMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);

    function NodeAsObject(Node: TTreeNode): TObject;
    function NodeAsStory(Node: TTreeNode): TStory;
    function NodeAsChapter(Node: TTreeNode): TChapter;
    function NodeAsScene(Node: TTreeNode): TScene;

    procedure PrepareToolBar();
    procedure ReLoad();
    procedure SelectedNodeChanged();

    procedure AddStory();
    procedure EditStory();
    procedure DeleteStory();

    procedure AddChapter();
    procedure EditChapter();
    procedure DeleteChapter();

    procedure AddScene();
    procedure EditScene();
    procedure DeleteScene();

    procedure EditItem();
    procedure DeleteItem();
    procedure EditItemText();

    procedure ExportStory();

    procedure MoveStory(Story: TStory; Node: TTreeNode; Up: Boolean);
    procedure MoveChapter(Chapter: TChapter; Node: TTreeNode; Up: Boolean);
    procedure MoveScene(Scene: TScene; Node: TTreeNode; Up: Boolean);
    procedure MoveNode(Up: Boolean);

    procedure ChangeParent();
    procedure CollapseAll();
    procedure ExpandAll();
  public
    constructor Create(AOwner: TComponent); override;
    procedure ControlInitialize; override;
    procedure ControlInitializeAfter(); override;
  end;

implementation

{$R *.lfm}

uses
  Tripous.IconList
  ,o_App

  ,fr_Scene
  ;



{ TfrStoryList }

constructor TfrStoryList.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  App.OnProjectOpened := AppOnProjectOpened;
  App.OnProjectClosed := AppOnProjectClosed;
  App.OnProjectMetricsChanged := AppOnProjectMetricsChanged;

  tv.ReadOnly := True ;
  tv.OnDblClick := TreeViewDblClick;
  tv.OnMouseDown := TreeViewMouseDown;
end;

procedure TfrStoryList.ControlInitialize;
begin
  inherited ControlInitialize;

  ParentTabPage.Caption := 'Stories';

  PrepareToolBar();
  ReLoad();
end;

procedure TfrStoryList.ControlInitializeAfter();
begin
  inherited ControlInitializeAfter();
  pnlTop.Height := (Self.ClientHeight - Splitter.Height) div 2;
end;



procedure TfrStoryList.AnyClick(Sender: TObject);
begin
  if mnuAddStory = Sender then
    AddStory()
  else if mnuAddChapter = Sender then
    AddChapter()
  else if mnuAddScene = Sender then
    AddScene()
  else if btnEditItem = Sender then
    EditItem()
  else if btnDeleteItem = Sender then
    DeleteItem()
  else if btnEditText = Sender then
    EditItemText()
  else if btnExportStory = Sender then
    ExportStory()
  else if btnChangeParent = Sender then
    ChangeParent()
  else if btnExpandAll = Sender then
    ExpandAll()
  else if btnCollapseAll = Sender then
    CollapseAll()
  else if btnUp = Sender then
    MoveNode(True)
  else if btnDown = Sender then
    MoveNode(False)
{
mnuAddStory.Click += (s, e) => AddStory();
mnuAddChapter.Click += (s, e) => AddChapter();
mnuAddScene.Click += (s, e) => AddScene();
btnEditItem.Click += (s, e) => EditItem();
btnDeleteItem.Click += (s, e) => DeleteItem();
btnEditText.Click += (s, e) => EditItemText();
btnExportStory.Click += (s, e) => ExportStory();

btnChangeParent.Click += (s, e) => ChangeParent();

btnExpandAll.Click += (s, e) => ExpandAll();
btnCollapseAll.Click += (s, e) => CollapseAll();

btnUp.Click += (s, e) => MoveNode(Up: true);
btnDown.Click += (s, e) => MoveNode(Up: false);

btnAddItem : TToolButton;
btnEditItem : TToolButton;
btnDeleteItem : TToolButton;
btnEditText: TToolButton;
btnExportStory: TToolButton;
btnChangeParent: TToolButton;
btnCollapseAll: TToolButton;
btnExpandAll: TToolButton;
btnUp: TToolButton;
btnDown: TToolButton;
}




end;

procedure TfrStoryList.AppOnProjectOpened(Sender: TObject);
begin

end;

procedure TfrStoryList.AppOnProjectClosed(Sender: TObject);
begin

end;

procedure TfrStoryList.AppOnProjectMetricsChanged(Sender: TObject);
begin

end;

procedure TfrStoryList.TreeViewDblClick(Sender: TObject);
begin
  // TODO: Edit item title
end;

procedure TfrStoryList.TreeViewMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Node: TTreeNode;
begin
  if Button <> mbRight then Exit;

  Node := tv.GetNodeAt(X, Y);
  if not Assigned(Node) then Exit;

  tv.Selected := Node;
  EditItemText();
end;

procedure TfrStoryList.PrepareToolBar();
begin
  ToolBar.AutoSize := True;
  ToolBar.ButtonHeight := 32;
  ToolBar.ButtonWidth := 32;

  btnAddItem := IconList.AddButton(ToolBar, 'table_add', 'Add Chapter or Scene', nil);
  btnAddItem.Style := tbsDropDown;
  btnAddItem.DropdownMenu := mnuAddItem;
  mnuAddStory.OnClick := AnyClick;
  mnuAddChapter.OnClick := AnyClick;
  mnuAddScene.OnClick := AnyClick;
  btnEditItem := IconList.AddButton(ToolBar, 'table_edit', 'Edit', AnyClick);
  btnDeleteItem := IconList.AddButton(ToolBar, 'table_delete', 'Remove', AnyClick);
  IconList.AddSeparator(ToolBar);
  btnEditText := IconList.AddButton(ToolBar, 'page_edit', 'Edit Text', AnyClick);
  btnExportStory := IconList.AddButton(ToolBar, 'table_export', 'Export Story', AnyClick);
  btnChangeParent := IconList.AddButton(ToolBar, 'scroll_pane_tree', 'Export Story', AnyClick);
  btnCollapseAll := IconList.AddButton(ToolBar, 'Tree_Collapse', 'Change Parent', AnyClick);
  btnExpandAll := IconList.AddButton(ToolBar, 'Tree_Expand', 'Expand All', AnyClick);
  btnUp := IconList.AddButton(ToolBar, 'arrow_up', 'Move Up', AnyClick);
  btnDown := IconList.AddButton(ToolBar, 'arrow_down', 'Move Down', AnyClick);
end;

procedure TfrStoryList.ReLoad;
var
  i, j, k: Integer;
  StoryNode: TTreeNode;
  ChapterNode: TTreeNode;
  SceneNode: TTreeNode;
  Story: TStory;
  Chapter: TChapter;
  Scene: TScene;
begin
  tv.BeginUpdate;
  try
    tv.Items.Clear;

    if App.CurrentProject = nil then
      Exit;

    for i := 0 to App.CurrentProject.StoryList.Count - 1 do
    begin
      Story := TStory(App.CurrentProject.StoryList.Items[i]);

      StoryNode := tv.Items.Add(nil, Story.DisplayTitle);
      StoryNode.Data := Story;
      StoryNode.ImageIndex := 0;
      StoryNode.SelectedIndex := 0;

      for j := 0 to Story.ChapterList.Count - 1 do
      begin
        Chapter := TChapter(Story.ChapterList.Items[j]);

        ChapterNode := tv.Items.AddChild(StoryNode, Chapter.DisplayTitle);
        ChapterNode.Data := Chapter;
        ChapterNode.ImageIndex := 1;
        ChapterNode.SelectedIndex := 1;

        for k := 0 to Chapter.SceneList.Count - 1 do
        begin
          Scene := TScene(Chapter.SceneList.Items[k]);

          SceneNode := tv.Items.AddChild(ChapterNode, Scene.DisplayTitle);
          SceneNode.Data := Scene;
          SceneNode.ImageIndex := 2;
          SceneNode.SelectedIndex := 2;
        end;
      end;
    end;

  finally
    tv.EndUpdate;
  end;

  SelectedNodeChanged;
end;

procedure TfrStoryList.SelectedNodeChanged();
begin

end;

procedure TfrStoryList.AddStory();
begin

end;

procedure TfrStoryList.EditStory();
begin

end;

procedure TfrStoryList.DeleteStory();
begin

end;

procedure TfrStoryList.AddChapter();
begin

end;

procedure TfrStoryList.EditChapter();
begin

end;

procedure TfrStoryList.DeleteChapter();
begin

end;

procedure TfrStoryList.AddScene();
begin

end;

procedure TfrStoryList.EditScene();
begin

end;

procedure TfrStoryList.DeleteScene();
begin

end;

procedure TfrStoryList.EditItem();
begin

end;

procedure TfrStoryList.DeleteItem();
begin

end;

procedure TfrStoryList.EditItemText();
var
  Node: TTreeNode;
  Scene: TScene;
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  Node := tv.Selected;
  if not Assigned(Node) then
    Exit;

  Scene := NodeAsScene(Node);
  if Assigned(Scene) then
    App.ContentPagerHandler.ShowPage(TfrScene, Scene.Id, Scene);
  {
  if Node.Data is TScene then
  begin
    Scene := Node.Data as TScene;
    App.ContentPagerHandler.ShowPage(TfrScene, Scene.Id, Scene);
  end;
 {
 if (App.CurrentProject == null)
     return;

 TreeNode Node = tv.SelectedNode;
 if (Node == null)
     return;

 if (Node.Tag is Story)
     App.ContentPagerHandler.ShowPage(typeof(UC_Story), (Node.Tag as Story).Id, Node.Tag);
 else if (Node.Tag is Chapter)
    App.ContentPagerHandler.ShowPage(typeof(UC_Chapter), (Node.Tag as Chapter).Id, Node.Tag);
 else if (Node.Tag is Scene)
     App.ContentPagerHandler.ShowPage(typeof(UC_Scene), (Node.Tag as Scene).Id, Node.Tag);
 }
end;

procedure TfrStoryList.ExportStory();
begin

end;

procedure TfrStoryList.MoveStory(Story: TStory; Node: TTreeNode; Up: Boolean);
begin

end;

procedure TfrStoryList.MoveChapter(Chapter: TChapter; Node: TTreeNode;
  Up: Boolean);
begin

end;

procedure TfrStoryList.MoveScene(Scene: TScene; Node: TTreeNode; Up: Boolean);
begin

end;

procedure TfrStoryList.MoveNode(Up: Boolean);
begin

end;

procedure TfrStoryList.ChangeParent();
begin

end;

procedure TfrStoryList.CollapseAll();
begin

end;

procedure TfrStoryList.ExpandAll();
begin

end;






function TfrStoryList.NodeAsObject(Node: TTreeNode): TObject;
begin
  if Assigned(Node) and Assigned(Node.Data) then
    Result := TObject(Node.Data)
  else
    Result := nil;
end;

function TfrStoryList.NodeAsStory(Node: TTreeNode): TStory;
var
  Obj: TObject;
begin
  Result := nil;
  Obj := NodeAsObject(Node);
  if Obj is TStory then
    Result := TStory(Obj);
end;

function TfrStoryList.NodeAsChapter(Node: TTreeNode): TChapter;
var
  Obj: TObject;
begin
  Result := nil;
  Obj := NodeAsObject(Node);
  if Obj is TChapter then
    Result := TChapter(Obj);
end;

function TfrStoryList.NodeAsScene(Node: TTreeNode): TScene;
var
  Obj: TObject;
begin
  Result := nil;
  try
    Obj := NodeAsObject(Node);
    if Obj is TScene then
      Result := TScene(Obj);
  except
  end;
end;

end.

