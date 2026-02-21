program StoryWriter;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  {$IFDEF HASAMIGA}
  athreads,
  {$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms
  , Tripous
  , Tripous.IconList
  , Tripous.Broadcaster
  , o_App
  , o_AppSettings
  , o_Entities
  , o_PageHandler
  , o_SearchAndReplace
  , o_ProjectGlobalSearch
  , o_Consts
  , f_MainForm
  , f_FindAndReplaceDialog
  , fr_FramePage
  , fr_TextEditor
  , fr_MarkdownPreview
  , fr_StoryList
  , fr_CategoryList
  , fr_TagList
  , fr_ComponentList
  , fr_Search
  , fr_QuickView
  , fr_NoteList
  , fr_Scene
  , fr_Chapter
  , fr_Story
  , fr_Note
  , fr_Component
  , fr_TempText
  , f_EditComponentDialog
  , f_EditItemDialog, f_SelectParentDialog, f_ProjectEditDialog, 
f_AppSettingsDialog, o_TextStats, o_GlobalSearchTerm, o_Cli, o_GitCli, 
f_GitCommitMessageDialog, o_Wiki, o_ExportOptions, o_StoryExporter, 
f_ExportDialog;

{$R *.res}

begin
  RequireDerivedFormResource:=True;
  Application.Scaled:=True;
  {$PUSH}{$WARN 5044 OFF}
  Application.MainFormOnTaskbar:=True;
  {$POP}
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.

