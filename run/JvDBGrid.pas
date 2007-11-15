{-----------------------------------------------------------------------------
The contents of this file are subject to the Mozilla Public License
Version 1.1 (the "License"); you may not use this file except in compliance
with the License. You may obtain a copy of the License at
http://www.mozilla.org/MPL/MPL-1.1.html

Software distributed under the License is distributed on an "AS IS" basis,
WITHOUT WARRANTY OF ANY KIND, either expressed or implied. See the License for
the specific language governing rights and limitations under the License.

The Original Code is: JvDBGrid.PAS, released on 2002-07-04.

The Initial Developers of the Original Code are: Fedor Koshevnikov, Igor Pavluk and Serge Korolev
Copyright (c) 1997, 1998 Fedor Koshevnikov, Igor Pavluk and Serge Korolev
Copyright (c) 2001,2002 SGB Software
All Rights Reserved.

Contributor(s):
  Polaris Software
  Lionel Reynaud
  Flemming Brandt Clausen
  Fr�d�ric Leneuf-Magaud
  Andreas Hausladen

You may retrieve the latest version of this file at the Project JEDI's JVCL home page,
located at http://jvcl.sourceforge.net

-----------------------------------------------------------------------------

INFO: Draw events are triggered in this order:

- Title cells:
OnGetBtnParams
OnDrawColumnTitle

- Data cells:
OnGetCellParams
OnDrawColumnCell

OnGetCellProps and OnDrawDataCell are obsolete.

-----------------------------------------------------------------------------

KNOWN ISSUES:

- THE ColLines OPTION DOES NOT WORK WELL WITH HIDDEN COLUMNS - BUG SOURCE: DBGRID.PAS
  If a column is followed by hidden columns and ColLines is set to False, the display size
  of the column is smaller than its width. This is easy to notice when you give the focus
  to the cell (the focus rect is truncated) or when you use the AutoSize feature (there's
  a gap after the last column). This bug comes from DBGrid.pas.

-----------------------------------------------------------------------------
2004/07/08 - WPostma merged changes by Fr�d�ric Leneuf-Magaud and ahuser.}

// $Id$

unit JvDBGrid;

{$I jvcl.inc}

interface

uses
  {$IFDEF UNITVERSIONING}
  JclUnitVersioning,
  {$ENDIF UNITVERSIONING}
  {$IFDEF HAS_UNIT_TYPES}
  Types,
  {$ENDIF HAS_UNIT_TYPES}
  {$IFDEF CLR}
  WinUtils,
  {$ENDIF CLR}
  Windows, Messages, Classes, Graphics, Controls, Grids, Menus, DBGrids, DB,
  StdCtrls, Forms, Contnrs,
  JvTypes, {JvTypes contains Exception base class}
  JvAppStorage, JvFormPlacement, JvExDBGrids, JvDBUtils;

const
  DefJvGridOptions = [dgEditing, dgTitles, dgIndicator, dgColumnResize,
    dgColLines, dgRowLines, dgTabs, dgConfirmDelete, dgCancelOnExit];

  {$IFDEF BCB}
  {$NODEFINE DefJvGridOptions}
  {$ENDIF BCB}

  JvDefaultAlternateRowColor = TColor($00CCCCCC); // Light gray
  JvDefaultAlternateRowFontColor = TColor($00000000); // Black

  // Consts for AutoSizeColumnIndex
  JvGridResizeProportionally = -1;
  JvGridResizeLastVisibleCol = -2;

type
  TJvDBGrid = class;

  // Mantis 3895: The only way to lift an ambiguity in an event handler is to
  // redefine a type. A simple rename is not enough, hence the distinction
  // between BCB and the others.
  {$IFDEF BCB}
  TJvDBGridBitmap = class(TBitmap)
  end;
  {$ELSE}
  {$IFDEF DELPHI10_UP}
  TJvDBGridBitmap = class(TBitmap)
  end;
  {$ELSE}
  TJvDBGridBitmap = TBitmap;
  {$ENDIF DELPHI10_UP}
  {$ENDIF BCB}

  TSelectColumn = (scDataBase, scGrid);
  TTitleClickEvent = procedure(Sender: TObject; ACol: Longint;
    Field: TField) of object;
  TCheckTitleBtnEvent = procedure(Sender: TObject; ACol: Longint;
    Field: TField; var Enabled: Boolean) of object;
  TGetCellParamsEvent = procedure(Sender: TObject; Field: TField;
    AFont: TFont; var Background: TColor; Highlight: Boolean) of object;
  TSortMarker = (smNone, smDown, smUp);
  TGetBtnParamsEvent = procedure(Sender: TObject; Field: TField;
    AFont: TFont; var Background: TColor; var ASortMarker: TSortMarker;
    IsDown: Boolean) of object;
  TGetCellPropsEvent = procedure(Sender: TObject; Field: TField;
    AFont: TFont; var Background: TColor) of object; { obsolete }
  TJvDBEditShowEvent = procedure(Sender: TObject; Field: TField;
    var AllowEdit: Boolean) of object;
  TDrawColumnTitleEvent = procedure(Sender: TObject; ACanvas: TCanvas;
    ARect: TRect; AColumn: TColumn; var ASortMarker: TJvDBGridBitmap; IsDown: Boolean;
    var Offset: Integer; var DefaultDrawText,
    DefaultDrawSortMarker: Boolean) of object;
  TJvTitleHintEvent = procedure(Sender: TObject; Field: TField;
    var AHint: string; var ATimeOut: Integer) of object;
  TJvCellHintEvent = TJvTitleHintEvent;
  TJvDBColumnResizeEvent = procedure(Grid: TJvDBGrid; ACol: Longint; NewWidth: Integer) of object;
  TJvDBCheckIfBooleanFieldEvent = function(Grid: TJvDBGrid; Field: TField;
    var StringForTrue: string; var StringForFalse: string): Boolean of object;

  TJvDBGridLayoutChangeKind = (lcLayoutChanged, lcSizeChanged, lcTopLeftChanged);
  TJvDBGridLayoutChangeEvent = procedure(Grid: TJvDBGrid; Kind: TJvDBGridLayoutChangeKind) of object;
  TJvDBGridLayoutChangeLink = class
  private
    FOnChange: TJvDBGridLayoutChangeEvent;
  public
    procedure DoChange(Grid: TJvDBGrid; Kind: TJvDBGridLayoutChangeKind);
    property OnChange: TJvDBGridLayoutChangeEvent read FOnChange write FOnChange;
  end;

  EJVCLDbGridException = Class(EJVCLException);

  TJvSelectDialogColumnStrings = class(TPersistent)
  private
    FCaption: string;
    FRealNamesOption: string;
    FOK: string;
    FNoSelectionWarning: string;
  public
    constructor Create;
  published
    property Caption: string read FCaption write FCaption;
    property RealNamesOption: string read FRealNamesOption write FRealNamesOption;
    property OK: string read FOK write FOK;
    property NoSelectionWarning: string read FNoSelectionWarning write FNoSelectionWarning;
  end;

  TJvDBGridControlSize = (
    fcCellSize,     // Fit the control into the cell
    fcDesignSize,   // Leave the control as it was at design time
    fcBiggest       // Take the biggest size between Cell size and Design time size
  );

  TJvDBGridControl = class(TCollectionItem)
  private
    FControlName: string;
    FFieldName: string;
    FFitCell: TJvDBGridControlSize;
    FLeaveOnEnterKey: Boolean;
    FLeaveOnUpDownKey: Boolean;
    FDesignWidth: Integer;  // value set when needed by PlaceControl
    FDesignHeight: Integer; // value set when needed by PlaceControl
  public
    procedure Assign(Source: TPersistent); override;
  published
    property ControlName: string read FControlName write FControlName;
    property FieldName: string read FFieldName write FFieldName;
    property FitCell: TJvDBGridControlSize read FFitCell write FFitCell;
    property LeaveOnEnterKey: Boolean read FLeaveOnEnterKey write FLeaveOnEnterKey default False;
    property LeaveOnUpDownKey: Boolean read FLeaveOnUpDownKey write FLeaveOnUpDownKey default False;
  end;

  TJvDBGridControls = class(TCollection)
  private
    FParentDBGrid: TJvDBGrid;
    function GetItem(Index: Integer): TJvDBGridControl;
    procedure SetItem(Index: Integer; Value: TJvDBGridControl);
  protected
    function GetOwner: TPersistent; override;
  public
    constructor Create(ParentDBGrid: TJvDBGrid);
    function Add: TJvDBGridControl;
    function ControlByField(const FieldName: string): TJvDBGridControl;
    function ControlByName(const CtrlName: string): TJvDBGridControl;
    property Items[Index: Integer]: TJvDBGridControl read GetItem write SetItem; default;
  end;

  TCharList = set of Char;

  TJvGridPaintInfo = record
    MouseInCol: Integer; // the column that the mouse is in
    ColPressed: Boolean; // a column has been pressed
    ColPressedIdx: Integer; // idx of the pressed column
    ColSizing: Boolean; // currently sizing a column
    ColMoving: Boolean; // currently moving a column
  end;

  TJvDBGrid = class(TJvExDBGrid, IJvDataControl)
  private
    FAutoSort: Boolean;
    FBeepOnError: Boolean;
    FAutoAppend: Boolean;
    FSizingIndex: Integer;
    FSizingOfs: Integer;
    FShowGlyphs: Boolean;
    FDefaultDrawing: Boolean;
    FReduceFlicker: Boolean;
    FMultiSelect: Boolean;
    FSelecting: Boolean;
    FClearSelection: Boolean;
    FTitleButtons: Boolean;
    FPressedCol: TColumn;
    FPressed: Boolean;
    FTracking: Boolean;
    FSwapButtons: Boolean;
    FIniLink: TJvIniLink;
    FDisableCount: Integer;
    FFixedCols: Integer;
    FMsIndicators: TImageList;
    FOnCheckButton: TCheckTitleBtnEvent;
    FOnGetCellProps: TGetCellPropsEvent;
    FOnGetCellParams: TGetCellParamsEvent;
    FOnGetBtnParams: TGetBtnParamsEvent;
    {$IFDEF COMPILER6_UP}
    FOnEditChange: TNotifyEvent;
    {$ENDIF COMPILER6_UP}
    FOnTitleBtnClick: TTitleClickEvent;
    FOnTitleBtnDblClick: TTitleClickEvent;
    FOnTopLeftChanged: TNotifyEvent;
    FSelectionAnchor: TBookmarkStr;
    FOnDrawColumnTitle: TDrawColumnTitleEvent;
    FWord: string;
    FShowTitleHint: Boolean;
    FSortedField: string;
    FPostOnEnterKey: Boolean;
    FSelectColumn: TSelectColumn;
    FTitleArrow: Boolean;
    FTitlePopup: TPopupMenu;
    FOnShowTitleHint: TJvTitleHintEvent;
    FOnTitleArrowMenuEvent: TNotifyEvent;
    FAlternateRowColor: TColor;
    FAlternateRowFontColor: TColor;
    FAutoSizeColumns: Boolean;
    FAutoSizeColumnIndex: Integer;
    FMinColumnWidth: Integer;
    FMaxColumnWidth: Integer;
    FInAutoSize: Boolean;
    FSelectColumnsDialogStrings: TJvSelectDialogColumnStrings;
    FTitleColumn: TColumn;
    FOnColumnResized: TJvDBColumnResizeEvent;
    FSortMarker: TSortMarker;
    FShowCellHint: Boolean;
    FOnShowCellHint: TJvCellHintEvent;
    FCharList: TCharList;
    FScrollBars: TScrollStyle;
    FWordWrap: Boolean;
    FChangeLinks: TObjectList;
    FShowMemos: Boolean;
    FOnShowEditor: TJvDBEditShowEvent;
    FAlwaysShowEditor: Boolean;

    FControls: TJvDBGridControls;
    FCurrentControl: TWinControl;
    FOldControlWndProc: TWndMethod;
    FBooleanFieldToEdit: TField;
    FBooleanEditor: Boolean;
    FOnCheckIfBooleanField: TJvDBCheckIfBooleanFieldEvent;
    FStringForTrue: string;
    FStringForFalse: string;

    FAutoSizeRows: Boolean;
    FRowResize: Boolean;
    FRowsHeight: Integer;
    FTitleRowHeight: Integer;
    FCanDelete: Boolean;

    // XP Theming
    FUseXPThemes: Boolean;
    FPaintInfo: TJvGridPaintInfo;
    FCell: TGridCoord; // currently selected cell
    procedure CMMouseEnter(var Message: TMessage); message CM_MOUSEENTER;
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;

    procedure SetAutoSizeRows(Value: Boolean);
    procedure SetRowResize(Value: Boolean);
    procedure SetRowsHeight(Value: Integer);
    procedure SetTitleRowHeight(Value: Integer);

    procedure WriteCellText(ARect: TRect; DX, DY: Integer; const Text: string;
      Alignment: TAlignment; ARightToLeft: Boolean; FixCell: Boolean; Options: Integer = 0);
    function GetImageIndex(Field: TField): Integer;
    procedure SetShowGlyphs(Value: Boolean);
    function GetStorage: TJvFormPlacement;
    procedure SetStorage(Value: TJvFormPlacement);
    procedure IniSave(Sender: TObject);
    procedure IniLoad(Sender: TObject);
    procedure SetMultiSelect(Value: Boolean);
    procedure SetTitleButtons(Value: Boolean);
    procedure StopTracking;
    procedure TrackButton(X, Y: Integer);
    function ActiveRowSelected: Boolean;
    function GetSelCount: Longint;
    function GetRow: Longint;
    procedure SetRow(Value: Longint);
    procedure SaveColumnsLayout(const AppStorage: TJvCustomAppStorage; const Section: string);
    procedure RestoreColumnsLayout(const AppStorage: TJvCustomAppStorage; const Section: string);
    function GetOptions: TDBGridOptions;
    procedure SetOptions(Value: TDBGridOptions);
    function GetMasterColumn(ACol, ARow: Longint): TColumn;
    function GetTitleOffset: Byte;
    procedure SetFixedCols(Value: Integer);
    function GetFixedCols: Integer;
    function CalcLeftColumn: Integer;
    procedure WMChar(var Msg: TWMChar); message WM_CHAR;
    procedure WMCancelMode(var Msg: TMessage); message WM_CANCELMODE;
    procedure WMRButtonUp(var Msg: TWMMouse); message WM_RBUTTONUP;
    procedure CMHintShow(var Msg: TCMHintShow); message CM_HINTSHOW;
    procedure SetTitleArrow(const Value: Boolean);
    procedure ShowSelectColumnClick;
    procedure SetAlternateRowColor(const Value: TColor);
    procedure ReadAlternateRowColor(Reader: TReader);
    procedure SetAlternateRowFontColor(const Value: TColor);
    procedure ReadAlternateRowFontColor(Reader: TReader);
    procedure SetAutoSizeColumnIndex(const Value: Integer);
    procedure SetAutoSizeColumns(const Value: Boolean);
    procedure SetMaxColumnWidth(const Value: Integer);
    procedure SetMinColumnWidth(const Value: Integer);
    procedure SetSelectColumnsDialogStrings(const Value: TJvSelectDialogColumnStrings);
    procedure SetSortedField(const Value: string);
    procedure SetSortMarker(const Value: TSortMarker);
    procedure WMVScroll(var Msg: TWMVScroll); message WM_VSCROLL;
    procedure SetShowMemos(const Value: Boolean);
    procedure SetBooleanEditor(const Value: Boolean);
    procedure SetScrollBars(const Value: TScrollStyle);
    procedure ReadPostOnEnter(Reader: TReader);

    procedure SetControls(Value: TJvDBGridControls);
    procedure HideCurrentControl;
    procedure ControlWndProc(var Message: TMessage);
    procedure ChangeBoolean(const FieldValueChange: Shortint);
    function EditWithBoolBox(Field: TField): Boolean; {$IFDEF DELPHI9} inline; {$ENDIF DELPHI9}
    function DoKeyPress(var Msg: TWMChar): Boolean;
    procedure SetWordWrap(Value: Boolean);
    procedure NotifyLayoutChange(const Kind: TJvDBGridLayoutChangeKind);

    // XP Theming
    procedure SetUseXPThemes(Value: Boolean);
    {$IFDEF JVCLThemesEnabled}
    function ColumnOffset: Integer; // col offset used for calculations. Is 1 if indicator is being displayed
    function ValidCell(ACell: TGridCoord): Boolean;
    {$ENDIF JVCLThemesEnabled}
  protected
    FCurrentDrawRow: Integer;
    procedure MouseLeave(Control: TControl); override;
    function AcquireFocus: Boolean;
    function CanEditShow: Boolean; override;
    function CreateEditor: TInplaceEdit; override;
    procedure DblClick; override;
    function DoTitleBtnDblClick: Boolean; dynamic;

    procedure DoTitleClick(ACol: Longint; AField: TField); dynamic;
    procedure CheckTitleButton(ACol, ARow: Longint; var Enabled: Boolean); dynamic;
    function SortMarkerAssigned(const AFieldName: string): Boolean; dynamic;
    function ChangeSortMarker(const Value: TSortMarker): Boolean;
    procedure CallDrawCellEvent(ACol, ARow: Longint; ARect: TRect; AState: TGridDrawState);
    procedure DoDrawCell(ACol, ARow: Longint; ARect: TRect; AState: TGridDrawState); virtual;
    procedure DrawCell(ACol, ARow: Longint; ARect: TRect; AState: TGridDrawState); override;
    procedure DrawDataCell(const Rect: TRect; Field: TField;
      State: TGridDrawState); override; { obsolete from Delphi 2.0 }

    function BeginColumnDrag(var Origin: Integer; var Destination: Integer; const MousePt: TPoint): Boolean; override;
    procedure ColumnMoved(FromIndex: Integer; ToIndex: Integer); override;
    function AllowTitleClick: Boolean; virtual;

    {$IFDEF COMPILER6_UP}
    procedure EditChanged(Sender: TObject); dynamic;
    {$ENDIF COMPILER6_UP}
    procedure GetCellProps(Field: TField; AFont: TFont; var Background: TColor;
      Highlight: Boolean); dynamic;
    function HighlightCell(DataCol, DataRow: Integer; const Value: string;
      AState: TGridDrawState): Boolean; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure KeyPress(var Key: Char); override;
    procedure SetColumnAttributes; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    function DoMouseWheelDown(Shift: TShiftState; MousePos: TPoint): Boolean; override;
    function DoMouseWheelUp(Shift: TShiftState; MousePos: TPoint): Boolean; override;
    procedure Scroll(Distance: Integer); override;
    procedure LayoutChanged; override;
    procedure TopLeftChanged; override;
    procedure GridInvalidateRow(Row: Longint);
    procedure DrawColumnCell(const Rect: TRect; DataCol: Integer;
      Column: TColumn; State: TGridDrawState); override;
    procedure ColWidthsChanged; override;
    function DoEraseBackground(Canvas: TCanvas; Param: Integer): Boolean; override;
    procedure Paint; override;
    procedure CalcSizingState(X, Y: Integer; var State: TGridState;
      var Index: Longint; var SizingPos, SizingOfs: Integer;
      var FixedInfo: TGridDrawInfo); override;
    procedure DoDrawColumnTitle(ACanvas: TCanvas; ARect: TRect; AColumn: TColumn;
      var ASortMarker: TJvDBGridBitmap; IsDown: Boolean; var Offset: Integer;
      var DefaultDrawText, DefaultDrawSortMarker: Boolean); virtual;
    procedure ColEnter; override;
    procedure ColExit; override;

    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer;
      MousePos: TPoint): Boolean; override;
    procedure EditButtonClick; override;
    {$IFDEF COMPILER5}
    procedure FocusCell(ACol, ARow: Longint; MoveAnchor: Boolean);
    {$ENDIF COMPILER5}
    procedure CellClick(Column: TColumn); override;
    procedure DefineProperties(Filer: TFiler); override;
    procedure DoMinColWidth; virtual;
    procedure DoMaxColWidth; virtual;
    procedure DoAutoSizeColumns; virtual;
    procedure Resize; override;
    procedure Loaded; override;
    function GetMinColWidth(Default: Integer): Integer;
    function GetMaxColWidth(Default: Integer): Integer;
    function LastVisibleColumn: Integer;
    function FirstVisibleColumn: Integer;
    procedure TitleClick(Column: TColumn); override;
    procedure DoGetBtnParams(Field: TField; AFont: TFont; var Background: TColor;
      var ASortMarker: TSortMarker; IsDown: Boolean); virtual;

    procedure PlaceControl(Control: TWinControl; ACol, ARow: Integer); virtual;
    procedure RowHeightsChanged; override;
    function GetDataLink: TDataLink; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure DefaultDataCellDraw(const Rect: TRect; Field: TField; State: TGridDrawState);
    procedure DisableScroll;
    procedure EnableScroll;
    function ScrollDisabled: Boolean;
    procedure MouseToCell(X, Y: Integer; var ACol, ARow: Longint);
    procedure SelectAll;
    procedure UnselectAll;
    procedure ToggleRowSelection;
    procedure GotoSelection(Index: Longint);
    procedure LoadFromAppStore(const AppStorage: TJvCustomAppStorage; const Path: string);
    procedure SaveToAppStore(const AppStorage: TJvCustomAppStorage; const Path: string);
    procedure Load;
    procedure Save;
    procedure UpdateTabStops(ALimit: Integer = -1);
    procedure ShowColumnsDialog;
    procedure CloseControl; // Hide the current edit control and give the focus to the grid
    procedure InitializeColumnsWidth(const MinWidth, MaxWidth: Integer;
      const DisplayWholeTitle: Boolean; const FixedWidths: array of Integer);
    procedure MouseWheelHandler(var Message: TMessage); override;

    procedure RegisterLayoutChangeLink(Link: TJvDBGridLayoutChangeLink);
    procedure UnregisterLayoutChangeLink(Link: TJvDBGridLayoutChangeLink);

    property SelectedRows;
    property SelCount: Longint read GetSelCount;
    property Canvas;
    property Col;
    property InplaceEditor;
    property LeftCol;
    property Row: Longint read GetRow write SetRow;
    property CurrentDrawRow: Integer read FCurrentDrawRow;
    property VisibleRowCount;
    property VisibleColCount;
    property IndicatorOffset;
    property TitleOffset: Byte read GetTitleOffset;
    property CharList: TCharList read FCharList write FCharList;
    property ScrollBars: TScrollStyle read FScrollBars write SetScrollBars;
  published
    property AutoAppend: Boolean read FAutoAppend write FAutoAppend default True;
    property SortMarker: TSortMarker read FSortMarker write SetSortMarker default smNone;
    property AutoSort: Boolean read FAutoSort write FAutoSort default True;
    property Options: TDBGridOptions read GetOptions write SetOptions default DefJvGridOptions;
    property FixedCols: Integer read GetFixedCols write SetFixedCols default 0;
    property ClearSelection: Boolean read FClearSelection write FClearSelection default True;
    property DefaultDrawing: Boolean read FDefaultDrawing write FDefaultDrawing default True;
    property IniStorage: TJvFormPlacement read GetStorage write SetStorage;
    property MultiSelect: Boolean read FMultiSelect write SetMultiSelect default False;
    property ShowGlyphs: Boolean read FShowGlyphs write SetShowGlyphs default True;
    property TitleButtons: Boolean read FTitleButtons write SetTitleButtons default False;
    property OnCheckButton: TCheckTitleBtnEvent read FOnCheckButton write FOnCheckButton;
    property OnGetCellProps: TGetCellPropsEvent read FOnGetCellProps write FOnGetCellProps; { obsolete }
    property OnGetCellParams: TGetCellParamsEvent read FOnGetCellParams write FOnGetCellParams;
    property OnGetBtnParams: TGetBtnParamsEvent read FOnGetBtnParams write FOnGetBtnParams;
    {$IFDEF COMPILER6_UP}
    property OnEditChange: TNotifyEvent read FOnEditChange write FOnEditChange;
    property BevelEdges;
    property BevelInner;
    property BevelKind default bkNone;
    property BevelOuter;
    {$ENDIF COMPILER6_UP}
    property OnShowEditor: TJvDBEditShowEvent read FOnShowEditor write FOnShowEditor;
    property OnTitleBtnClick: TTitleClickEvent read FOnTitleBtnClick write FOnTitleBtnClick;
    property OnTitleBtnDblClick: TTitleClickEvent read FOnTitleBtnDblClick write FOnTitleBtnDblClick;
    property OnTopLeftChanged: TNotifyEvent read FOnTopLeftChanged write FOnTopLeftChanged;
    property OnDrawColumnTitle: TDrawColumnTitleEvent read FOnDrawColumnTitle write FOnDrawColumnTitle;
    property OnContextPopup;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
    property OnResize;
    property OnMouseWheelDown;
    property OnMouseWheelUp;
    property BeepOnError: Boolean read FBeepOnError write FBeepOnError default True;
    property AlternateRowColor: TColor read FAlternateRowColor write SetAlternateRowColor default clNone;
    property AlternateRowFontColor: TColor read FAlternateRowFontColor write SetAlternateRowFontColor default clNone;
    property PostOnEnterKey: Boolean read FPostOnEnterKey write FPostOnEnterKey default False;
    property SelectColumn: TSelectColumn read FSelectColumn write FSelectColumn default scDataBase;
    property SortedField: string read FSortedField write SetSortedField;
    property ShowTitleHint: Boolean read FShowTitleHint write FShowTitleHint default False;
    property TitleArrow: Boolean read FTitleArrow write SetTitleArrow default False;
    property TitlePopup: TPopupMenu read FTitlePopup write FTitlePopup;
    property OnShowTitleHint: TJvTitleHintEvent read FOnShowTitleHint write FOnShowTitleHint;
    property OnTitleArrowMenuEvent: TNotifyEvent read FOnTitleArrowMenuEvent write FOnTitleArrowMenuEvent;
    property ShowCellHint: Boolean read FShowCellHint write FShowCellHint default False;
    property OnShowCellHint: TJvCellHintEvent read FOnShowCellHint write FOnShowCellHint;
    property MaxColumnWidth: Integer read FMaxColumnWidth write SetMaxColumnWidth default 0;
    property MinColumnWidth: Integer read FMinColumnWidth write SetMinColumnWidth default 0;
    property AutoSizeColumns: Boolean read FAutoSizeColumns write SetAutoSizeColumns default False;
    property AutoSizeColumnIndex: Integer read FAutoSizeColumnIndex write SetAutoSizeColumnIndex
      default JvGridResizeProportionally;
    property SelectColumnsDialogStrings: TJvSelectDialogColumnStrings
      read FSelectColumnsDialogStrings write SetSelectColumnsDialogStrings;
    { Allows user to delete things using the "del" key }
    property CanDelete: Boolean read FCanDelete write FCanDelete default True;

    { EditControls: list of controls used to edit data }
    property EditControls: TJvDBGridControls read FControls write SetControls;
    { AutoSizeRows: are rows resized automatically ? }
    property AutoSizeRows: Boolean read FAutoSizeRows write SetAutoSizeRows default True;
    { ReduceFlicker: improve (but slow) the display when painting/scrolling ? }
    property ReduceFlicker: Boolean read FReduceFlicker write FReduceFlicker default True;
    { RowResize: can rows be resized with the mouse ? }
    property RowResize: Boolean read FRowResize write SetRowResize default False;
    { RowsHeight: data rows height }
    property RowsHeight: Integer read FRowsHeight write SetRowsHeight;
    { TitleRowHeight: title row height (cannot be resized with the mouse) }
    property TitleRowHeight: Integer read FTitleRowHeight write SetTitleRowHeight;
    { WordWrap: if true, titles, memo and string fields are displayed on several lines }
    property WordWrap: Boolean read FWordWrap write SetWordWrap default False;
    { ShowMemos: if true, memo fields are shown as text }
    property ShowMemos: Boolean read FShowMemos write SetShowMemos default True;
    { BooleanEditor: if true, a checkbox is used to edit boolean fields }
    property BooleanEditor: Boolean read FBooleanEditor write SetBooleanEditor default True;
    { UseXPThemes: if true, the grid is painted in the active XP theme style }
    property UseXPThemes: Boolean read FUseXPThemes write SetUseXPThemes default True;
    { OnCheckIfBooleanField: event used to treat integer fields and string fields as boolean fields }
    property OnCheckIfBooleanField: TJvDBCheckIfBooleanFieldEvent read FOnCheckIfBooleanField write FOnCheckIfBooleanField;
    { OnColumnResized: event triggered each time a column is resized with the mouse }
    property OnColumnResized: TJvDBColumnResizeEvent read FOnColumnResized write FOnColumnResized;
  end;

{$IFDEF UNITVERSIONING}
const
  UnitVersioning: TUnitVersionInfo = (
    RCSfile: '$URL$';
    Revision: '$Revision$';
    Date: '$Date$';
    LogPath: 'JVCL\run'
  );
{$ENDIF UNITVERSIONING}

implementation

uses
  {$IFDEF CLR}
  System.Reflection,
  {$ENDIF CLR}
  {$IFDEF HAS_UNIT_VARIANTS}
  Variants,
  {$ENDIF HAS_UNIT_VARIANTS}
  SysUtils, Math, TypInfo, Dialogs, DBConsts,
  {$IFDEF COMPILER6_UP}
  StrUtils,
  JvDBLookup,
  {$ENDIF COMPILER6_UP}
  JvVCL5Utils,
  JvConsts, JvResources, JvThemes, JvJCLUtils, JvJVCLUtils,
  {$IFDEF COMPILER7_UP}
  GraphUtil, // => TScrollDirection, DrawArray(must be after JvJVCLUtils)
  {$ENDIF COMPILER7_UP}
  JvAppStoragePropertyEngineDB, JvDBGridSelectColumnForm;

{$R JvDBGrid.res}

type
  {$IFNDEF CLR}
  TBookmarks = class(TBookmarkList);
  {$ENDIF ~CLR}
  TGridPicture = (gpBlob, gpMemo, gpPicture, gpOle, gpObject, gpData,
    gpNotEmpty, gpMarkDown, gpMarkUp, gpChecked, gpUnChecked, gpPopup);
  {$IFNDEF COMPILER7_UP}
  TScrollDirection = (sdLeft, sdRight, sdUp, sdDown);
  {$ENDIF ~COMPILER7_UP}

const
  GridBmpNames: array [TGridPicture] of {$IFDEF CLR}string{$ELSE}PChar{$ENDIF} =
  ('JvDBGridBLOB', 'JvDBGridMEMO', 'JvDBGridPICT', 'JvDBGridOLE', 'JvDBGridOBJECT',
    'JvDBGridDATA', 'JvDBGridNOTEMPTY', 'JvDBGridSMDOWN', 'JvDBGridSMUP',
    'JvDBGridCHECKED', 'JvDBGridUNCHECKED', 'JvDBGridPOPUP');

  bmMultiDot = 'JvDBGridMSDOT';
  bmMultiArrow = 'JvDBGridMSARROW';

  // Consts for ChangeBoolean
  JvGridBool_INVERT = 9;
  JvGridBool_CHECK = 0;
  JvGridBool_UNCHECK = -1;

var
  GridBitmaps: array [TGridPicture] of TJvDBGridBitmap =
    (nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil);
  FirstGridBitmaps: Boolean = True;

procedure FinalizeGridBitmaps;
var
  I: TGridPicture;
begin
  for I := Low(TGridPicture) to High(TGridPicture) do
    FreeAndNil(GridBitmaps[I]);
end;

function GetGridBitmap(BmpType: TGridPicture): TJvDBGridBitmap;
begin
  if GridBitmaps[BmpType] = nil then
  begin
    if FirstGridBitmaps then
      FirstGridBitmaps := False;
    GridBitmaps[BmpType] := TJvDBGridBitmap.Create;
    GridBitmaps[BmpType].LoadFromResourceName(HInstance, GridBmpNames[BmpType]);
  end;
  Result := GridBitmaps[BmpType];
end;

{$IFNDEF COMPILER7_UP}
 {$IFDEF JVCLThemesEnabled}
procedure DrawArrow(ACanvas: TCanvas; Direction: TScrollDirection;
  Location: TPoint; Size: Integer);
const
  ArrowPts: array[TScrollDirection, 0..2] of TPoint =
    (((X:1; Y:0), (X:0; Y:1), (X:1; Y:2)),
     ((X:0; Y:0), (X:1; Y:1), (X:0; Y:2)),
     ((X:0; Y:1), (X:1; Y:0), (X:2; Y:1)),
     ((X:0; Y:0), (X:1; Y:1), (X:2; Y:0)));
var
  I: Integer;
  Pts: array[0..2] of TPoint;
  OldWidth: Integer;
  OldColor: TColor;
begin
  if ACanvas = nil then exit;
  OldColor := ACanvas.Brush.Color;
  ACanvas.Brush.Color := ACanvas.Pen.Color;
  Move(ArrowPts[Direction], Pts, SizeOf(Pts));
  for I := 0 to 2 do
    Pts[I] := Point(Pts[I].x * Size + Location.X, Pts[I].y * Size + Location.Y);
  with ACanvas do
  begin
    OldWidth := Pen.Width;
    Pen.Width := 1;
    Polygon(Pts);
    Pen.Width := OldWidth;
    Brush.Color := OldColor;
  end;
end;
 {$ENDIF JVCLThemesEnabled}
{$ENDIF ~COMPILER7_UP}

//=== { TInternalInplaceEdit } ===============================================

{$IFDEF COMPILER6_UP}

type
  TInternalInplaceEdit = class(TInplaceEditList)
  private
    FDataList: TJvDBLookupList; //  TDBLookupListBox
    FUseDataList: Boolean;
    FLookupSource: TDataSource;
  protected
    procedure CloseUp(Accept: Boolean); override;
    procedure DoEditButtonClick; override;
    procedure DropDown; override;
    procedure UpdateContents; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer;
      MousePos: TPoint): Boolean; override;
  public
    constructor Create(Owner: TComponent); override;
    property DataList: TJvDBLookupList read FDataList; //  TDBLookupListBox
    property OnChange;
  end;

constructor TInternalInplaceEdit.Create(Owner: TComponent);
begin
  inherited Create(Owner);
  FLookupSource := TDataSource.Create(Self);
end;

procedure TInternalInplaceEdit.CloseUp(Accept: Boolean);
var
  MasterField: TField;
  ListValue: Variant;
begin
  if ListVisible then
  begin
    if GetCapture <> 0 then
      SendMessage(GetCapture, WM_CANCELMODE, 0, 0);
    if ActiveList = DataList then
      ListValue := DataList.KeyValue
    else
    if PickList.ItemIndex <> -1 then
      ListValue := PickList.Items[PickList.ItemIndex]
    else
      ListValue := Null;
    SetWindowPos(ActiveList.Handle, 0, 0, 0, 0, 0, SWP_NOZORDER or
      SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE or SWP_HIDEWINDOW);
    ListVisible := False;
    if Assigned(FDataList) then
      FDataList.LookupSource := nil; //  ListSource
    FLookupSource.DataSet := nil;
    Invalidate;
    if Accept then
      if ActiveList = DataList then
        with TCustomDBGrid(Grid), TDBGrid(Grid).Columns[SelectedIndex].Field do
        begin
          MasterField := DataSet.FieldByName(KeyFields);
          if MasterField.CanModify and (Grid as IJvDataControl).GetDataLink.Edit then
            MasterField.Value := ListValue;
        end
      else
      if (not VarIsNull(ListValue)) and EditCanModify then
        with TCustomDBGrid(Grid), TDBGrid(Grid).Columns[SelectedIndex].Field do
          Text := ListValue;
  end;
end;

procedure TInternalInplaceEdit.DoEditButtonClick;
begin
  TJvDBGrid(Grid).EditButtonClick; //   TCustomDBGrid
end;

procedure TInternalInplaceEdit.DropDown;
var
  Column: TColumn;
begin
  if not ListVisible then
  begin
    with TDBGrid(Grid) do
      Column := Columns[SelectedIndex];
    if ActiveList = FDataList then
      with Column.Field do
      begin
        FDataList.Color := Color;
        FDataList.Font := Font;
        FDataList.RowCount := Column.DropDownRows;
        FLookupSource.DataSet := LookupDataSet;
        FDataList.LookupField := LookupKeyFields; //  KeyField
        FDataList.LookupDisplay := LookupResultField; //  ListField
        FDataList.LookupSource := FLookupSource; //  ListSource
        FDataList.KeyValue := DataSet.FieldByName(KeyFields).Value;
      end
    else
    if ActiveList = PickList then
    begin
      PickList.Items.Assign(Column.PickList);
      DropDownRows := Column.DropDownRows;
    end;
  end;
  inherited DropDown;
end;

procedure TInternalInplaceEdit.UpdateContents;
var
  Column: TColumn;
begin
  inherited UpdateContents;
  if FUseDataList then
  begin
    if FDataList = nil then
    begin
      FDataList := TJvPopupDataList.Create(Self);
      FDataList.Visible := False;
      FDataList.Parent := Self;
      FDataList.OnMouseUp := ListMouseUp;
    end;
    ActiveList := FDataList;
  end;
  with TDBGrid(Grid) do
    Column := Columns[SelectedIndex];
  Self.ReadOnly := Column.ReadOnly;
  Font.Assign(Column.Font);
  ImeMode := Column.ImeMode;
  ImeName := Column.ImeName;
end;

type
  TSelection = record
    StartPos: Integer;
    EndPos: Integer;
  end;

procedure TInternalInplaceEdit.KeyDown(var Key: Word; Shift: TShiftState);

  procedure SendToParent;
  begin
    TJvDBGrid(Grid).KeyDown(Key, Shift);
    Key := 0;
  end;

  procedure ParentEvent;
  var
    GridKeyDown: TKeyEvent;
  begin
    GridKeyDown := TJvDBGrid(Grid).OnKeyDown;
    if Assigned(GridKeyDown) then
      GridKeyDown(Grid, Key, Shift);
  end;

  function ForwardMovement: Boolean;
  begin
    Result := dgAlwaysShowEditor in TDBGrid(Grid).Options;
  end;

  function Ctrl: Boolean;
  begin
    Result := (Shift * KeyboardShiftStates = [ssCtrl]);
  end;

  function Selection: TSelection;
  begin
    {$IFDEF CLR}
    SendGetIntMessage(Handle, EM_GETSEL, Result.StartPos, Result.EndPos);
    {$ELSE}
    SendMessage(Handle, EM_GETSEL, WPARAM(@Result.StartPos), LPARAM(@Result.EndPos));
    {$ENDIF CLR}
  end;

  function CaretPos: Integer;
  var
    P: TPoint;
  begin
    Windows.GetCaretPos(P);
    Result := SendMessage(Handle, EM_CHARFROMPOS, 0, MakeLong(P.X, P.Y));
  end;

  function RightSide: Boolean;
  begin
    with Selection do
      Result := {(CaretPos = GetTextLen) and  }
        ((StartPos = 0) or (EndPos = StartPos)) and (EndPos = GetTextLen);
  end;

  function LeftSide: Boolean;
  begin
    with Selection do
      Result := (CaretPos = 0) and (StartPos = 0) and
        ((EndPos = 0) or (EndPos = GetTextLen));
  end;

begin
  case Key of
    VK_LEFT:
      if ForwardMovement and (Ctrl or LeftSide) then
        SendToParent;
    VK_RIGHT:
      if ForwardMovement and (Ctrl or RightSide) then
        SendToParent;
  end;
  inherited KeyDown(Key, Shift);
end;

function TInternalInplaceEdit.DoMouseWheel(Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint): Boolean;
var
  DataLink: TDataLink;
begin
  // Do not validate a record by error
  DataLink := (Grid as IJvDataControl).GetDataLink;
  if DataLink.Active and (DataLink.DataSet.State <> dsBrowse) then
    DataLink.DataSet.Cancel;

  // Ideally we would transmit the action to the DatalList but
  // DoMouseWheel is protected
  //  Result := FDataList.DoMouseWheel(Shift, WheelDelta, MousePos);
  Result := inherited DoMouseWheel(Shift, WheelDelta, MousePos);
end;

{$ENDIF COMPILER6_UP}

//=== { TJvDBGridLayoutChangeLink } ==========================================

procedure TJvDBGridLayoutChangeLink.DoChange(Grid: TJvDBGrid;
  Kind: TJvDBGridLayoutChangeKind);
begin
  if Assigned(OnChange) then
    OnChange(Grid, Kind);
end;

//=== { TJvDBGridControls } ==================================================

constructor TJvDBGridControls.Create(ParentDBGrid: TJvDBGrid);
begin
  inherited Create(TJvDBGridControl);
  FParentDBGrid := ParentDBGrid;
end;

procedure TJvDBGridControl.Assign(Source: TPersistent);
begin
  if Source is TJvDBGridControl then
  begin
    ControlName := TJvDBGridControl(Source).ControlName;
    FieldName := TJvDBGridControl(Source).FieldName;
    FitCell := TJvDBGridControl(Source).FitCell;
    LeaveOnEnterKey := TJvDBGridControl(Source).LeaveOnEnterKey;
    LeaveOnUpDownKey := TJvDBGridControl(Source).LeaveOnUpDownKey;
    FDesignWidth := 0;
    FDesignHeight := 0;
  end
  else
    inherited Assign(Source);
end;

function TJvDBGridControls.GetOwner: TPersistent;
begin
  Result := FParentDBGrid;
end;

function TJvDBGridControls.Add: TJvDBGridControl;
begin
  Result := TJvDBGridControl(inherited Add);
end;

function TJvDBGridControls.GetItem(Index: Integer): TJvDBGridControl;
begin
  Result := TJvDBGridControl(inherited GetItem(Index));
end;

procedure TJvDBGridControls.SetItem(Index: Integer; Value: TJvDBGridControl);
begin
  inherited SetItem(Index, Value);
end;

function TJvDBGridControls.ControlByField(const FieldName: string): TJvDBGridControl;
var
  Ctrl_Idx: Integer;
begin
  Result := nil;
  for Ctrl_Idx := 0 to Count - 1 do
    if AnsiSameText(Items[Ctrl_Idx].FieldName, FieldName) then
    begin
      Result := Items[Ctrl_Idx];
      Break;
    end;
end;

function TJvDBGridControls.ControlByName(const CtrlName: string): TJvDBGridControl;
var
  Ctrl_Idx: Integer;
begin
  Result := nil;
  for Ctrl_Idx := 0 to Count - 1 do
    if AnsiSameText(Items[Ctrl_Idx].ControlName, CtrlName) then
    begin
      Result := Items[Ctrl_Idx];
      Break;
    end;
end;

//=== { TJvDBGrid } ==========================================================

constructor TJvDBGrid.Create(AOwner: TComponent);
var
  Bmp: TBitmap;
begin
  inherited Create(AOwner);
  inherited DefaultDrawing := False;
  inherited Options := inherited Options - [dgAlwaysShowEditor];

  // (obones): issue 3026: need to create FChangeLinks at the beginning
  // so that any change can access the object. It seems that on some
  // foreign systems, the assignment to the Options property triggers
  // NotifyLayoutChange, so it needs the FChangeLinks object
  FChangeLinks := TObjectList.Create(False);

  FAutoSort := True;
  FBeepOnError := True;
  Options := DefJvGridOptions;
  Bmp := TBitmap.Create;
  try
    Bmp.Handle := LoadBitmap(HInstance, bmMultiDot);
    FMsIndicators := TImageList.CreateSize(Bmp.Width, Bmp.Height);
    FMsIndicators.AddMasked(Bmp, clWhite);
    Bmp.Handle := LoadBitmap(HInstance, bmMultiArrow);
    FMsIndicators.AddMasked(Bmp, clWhite);
  finally
    Bmp.Free;
  end;
  FIniLink := TJvIniLink.Create;
  FIniLink.OnSave := IniSave;
  FIniLink.OnLoad := IniLoad;
  FShowGlyphs := True;
  FDefaultDrawing := True;
  FReduceFlicker := True;
  FClearSelection := True;
  FAutoAppend := True;
  FAlternateRowColor := clNone;
  FAlternateRowFontColor := clNone;
  FSelectColumn := scDataBase;
  FAutoSizeColumnIndex := JvGridResizeProportionally;
  FSelectColumnsDialogStrings := TJvSelectDialogColumnStrings.Create;
  // Note to users: the second line may not compile on non western european
  // systems, in which case you should simply remove it and recompile.
  FCharList :=
    ['A'..'Z', 'a'..'z', ' ', '-', '+', '0'..'9', '.', ',', Backspace,
     '�', '�', '�', '�', '�', '�', '�', '�', '�', '�', '�', '�', '�', '�'];

  FControls := TJvDBGridControls.Create(Self);
  FBooleanEditor := True;
  FStringForTrue := '1';
  FStringForFalse := '0';

  FAutoSizeRows := True;
  FRowsHeight := DefaultRowHeight;
  FTitleRowHeight := RowHeights[0];
  FShowMemos := True;
  FCanDelete := True;

  // XP Theming
  FUseXPThemes := True;
  FPaintInfo.ColPressed := False;
  FPaintInfo.MouseInCol := -1;
  FPaintInfo.ColPressedIdx := -1;
  FPaintInfo.ColMoving := False;
  FPaintInfo.ColSizing := False;
  FCell.X := -1;
  FCell.Y := -1;
end;

destructor TJvDBGrid.Destroy;
begin
  HideCurrentControl;
  FControls.Free;

  FIniLink.Free;
  FMsIndicators.Free;
  FSelectColumnsDialogStrings.Free;

  FChangeLinks.Free;

  inherited Destroy;
end;

procedure TJvDBGrid.RegisterLayoutChangeLink(Link: TJvDBGridLayoutChangeLink);
begin
  FChangeLinks.Add(Link);
end;

procedure TJvDBGrid.UnregisterLayoutChangeLink(Link: TJvDBGridLayoutChangeLink);
begin
  FChangeLinks.Remove(Link);
end;

function TJvDBGrid.EditWithBoolBox(Field: TField): Boolean;
begin
  if FBooleanEditor then
  begin
    Result := (Field.DataType = ftBoolean);
    if (not Result) and Assigned(FOnCheckIfBooleanField) and
      (Field.DataType in [ftSmallint, ftInteger, ftLargeint, ftWord, ftString, ftWideString]) then
    begin
      FStringForTrue := '1';
      FStringForFalse := '0';
      Result := FOnCheckIfBooleanField(Self, Field, FStringForTrue, FStringForFalse);
    end;
  end
  else
    Result := False;
end;

function TJvDBGrid.GetImageIndex(Field: TField): Integer;
begin
  Result := -1;
  if FShowGlyphs and Assigned(Field) then
  begin
    case Field.DataType of
      ftBytes, ftVarBytes, ftBlob, ftTypedBinary:
        Result := Ord(gpBlob);
      ftGraphic:
        Result := Ord(gpPicture);
      ftParadoxOle, ftDBaseOle:
        Result := Ord(gpOle);
      ftCursor, ftReference, ftDataSet:
        Result := Ord(gpData);
      ftMemo, ftFmtMemo:
        if not ShowMemos then
          Result := Ord(gpMemo);
      ftOraBlob, ftOraClob:
        Result := Ord(gpBlob);
      ftBoolean:
        if BooleanEditor and not Field.IsNull then
          if Field.AsBoolean then
            Result := Ord(gpChecked)
          else
            Result := Ord(gpUnChecked);
      ftString, ftWideString:
        if EditWithBoolBox(Field) and not Field.IsNull then
          if AnsiSameText(Field.AsString, FStringForFalse) then
            Result := Ord(gpUnChecked)
          else
            Result := Ord(gpChecked);
      ftSmallint, ftInteger, ftLargeint, ftWord:
        if EditWithBoolBox(Field) and not Field.IsNull then
          if Field.AsInteger = 0 then
            Result := Ord(gpUnChecked)
          else
            Result := Ord(gpChecked);
    end;
  end;
end;

function TJvDBGrid.ActiveRowSelected: Boolean;
var
  Index: Integer;
begin
  if MultiSelect and DataLink.Active then
    Result := SelectedRows.Find(DataLink.DataSet.Bookmark, Index)
  else
    Result := False;
end;

function TJvDBGrid.HighlightCell(DataCol, DataRow: Integer;
  const Value: string; AState: TGridDrawState): Boolean;
begin
  Result := ActiveRowSelected;
  if not Result then
    Result := inherited HighlightCell(DataCol, DataRow, Value, AState);
end;

procedure TJvDBGrid.ToggleRowSelection;
begin
  if MultiSelect and DataLink.Active then
    with SelectedRows do
      CurrentRowSelected := not CurrentRowSelected;
end;

function TJvDBGrid.GetSelCount: Longint;
begin
  if MultiSelect and (DataLink <> nil) and DataLink.Active then
    Result := SelectedRows.Count
  else
    Result := 0;
end;

function TJvDBGrid.GetRow: Longint;
begin
  Result := inherited Row;
end;

procedure TJvDBGrid.SetRow(Value: Longint);
begin
  if Value <> Row then
  begin
    if DataLink.Active and (Value >= TopRow) and (Value <= VisibleRowCount) then
      DataLink.DataSet.MoveBy(Value - Row)
    else
    if FBeepOnError then
      SysUtils.Beep;
  end;
end;

procedure TJvDBGrid.SelectAll;
var
  ABookmark: TBookmark;
begin
  if MultiSelect and DataLink.Active then
  begin
    with DataLink.DataSet do
    begin
      if Bof and Eof then
        Exit;
      DisableControls;
      try
        ABookmark := GetBookmark;
        try
          First;
          while not Eof do
          begin
            SelectedRows.CurrentRowSelected := True;
            Next;
          end;
        finally
          try
            GotoBookmark(ABookmark);
          except
          end;
          FreeBookmark(ABookmark);
        end;
      finally
        EnableControls;
      end;
    end;
  end;
end;

procedure TJvDBGrid.UnselectAll;
begin
  if MultiSelect then
  begin
    SelectedRows.Clear;
    FSelecting := False;
  end;
end;

procedure TJvDBGrid.GotoSelection(Index: Longint);
begin
  if MultiSelect and DataLink.Active and (Index < SelectedRows.Count) and
    (Index >= 0) then
    {$IFDEF CLR}
    DataLink.DataSet.Bookmark := SelectedRows[Index];
    {$ELSE}
    DataLink.DataSet.GotoBookmark(Pointer(SelectedRows[Index]));
    {$ENDIF}
end;

procedure TJvDBGrid.LayoutChanged;
var
  ACol: Longint;
begin
  ACol := Col;
  inherited LayoutChanged;
  if DataLink.Active and (FixedCols > 0) then
    Col := Min(Max(CalcLeftColumn, ACol), ColCount - 1);
  DoMinColWidth;
  DoMaxColWidth;
  DoAutoSizeColumns;

  NotifyLayoutChange(lcLayoutChanged);
end;

procedure TJvDBGrid.NotifyLayoutChange(const Kind: TJvDBGridLayoutChangeKind);
var
  I: Integer;
begin
  // We cannot trigger DataLink.LayoutChanged nor rely on it, so we notify any linked
  // control of the layout changes by calling DoChange on the registered
  // TJvDBGridLayoutChangeLink objects
  for I := 0 to FChangeLinks.Count-1 do
    TJvDBGridLayoutChangeLink(FChangeLinks[I]).DoChange(Self, Kind);

  if FCurrentControl <> nil then
    if FCurrentControl.Visible then
      PlaceControl(FCurrentControl, Col, Row);
end;

procedure TJvDBGrid.ColWidthsChanged;

  { VCL BUGFIX:
    The TCustomDBGrid.ColWidthsChanged method invokes DataLink.LayoutChanged/DataSource.OnDataChange
    for every column, regardless if it was resized or not.

    This causes a db-aware component or an DataSource.OnDataChange event handler to
    be triggered very often even if there was no actual change. This becomes worse
    when the assigned DataSet contains many visible fields (=>columns) and the DataChange
    event is used to update details data. }
    
  procedure FixedInheritedColWidthsChanged;
  var
    I, ChangeCount: Integer;
  begin
    //inherited TCustomGrid.ColWidthsChanged;
    inherited RowHeightsChanged; // does the same that TCustomGrid.ColWidthsChanged does.

    if (Datalink.Active or (Columns.State = csCustomized)) and
      AcquireLayoutLock then
    try
      ChangeCount := 0;
      for I := IndicatorOffset to ColCount - 1 do
        if Columns[I - IndicatorOffset].Width <> ColWidths[I] then
        begin
          Inc(ChangeCount);
          if ChangeCount > 1 then // we have what we need
            Break;
        end;
      if ChangeCount > 0 then
      begin
        if ChangeCount > 1 then
          DataLink.DataSet.DisableControls;
        try
          for I := IndicatorOffset to ColCount - 1 do
            if Columns[I - IndicatorOffset].Width <> ColWidths[I] then
              Columns[I - IndicatorOffset].Width := ColWidths[I];
        finally
          if ChangeCount > 1 then
            DataLink.DataSet.EnableControls;
        end;
      end;
    finally
      EndLayout;
    end;
  end;

var
  ACol: Longint;
begin
  ACol := Col;
  FixedInheritedColWidthsChanged;
  if DataLink.Active and (FixedCols > 0) then
    Col := Min(Max(CalcLeftColumn, ACol), ColCount - 1);
  DoMinColWidth;
  DoMaxColWidth;
  DoAutoSizeColumns;
end;

function TJvDBGrid.CreateEditor: TInplaceEdit;
begin
  {$IFDEF COMPILER6_UP}
  Result := TInternalInplaceEdit.Create(Self);
  // replace the call to default constructor :
  //  Result := inherited CreateEditor;
  TInternalInplaceEdit(Result).OnChange := EditChanged;
  {$ELSE}
  Result := inherited CreateEditor;
  {$ENDIF COMPILER6_UP}
end;

function TJvDBGrid.GetTitleOffset: Byte;
var
  I, J: Integer;
begin
  Result := 0;
  if dgTitles in Options then
  begin
    Result := 1;
    if (DataLink <> nil) and (DataLink.DataSet <> nil) and
      DataLink.DataSet.ObjectView then
      for I := 0 to Columns.Count - 1 do
      begin
        if Columns[I].Showing then
        begin
          J := Columns[I].Depth;
          if J >= Result then
            Result := J + 1;
        end;
      end;
  end;
end;

procedure TJvDBGrid.SetColumnAttributes;
begin
  inherited SetColumnAttributes;
  SetFixedCols(FFixedCols);
end;

procedure TJvDBGrid.SetFixedCols(Value: Integer);
var
  FixCount, I: Integer;
begin
  FixCount := Max(Value, 0) + IndicatorOffset;
  if DataLink.Active and not (csLoading in ComponentState) and
    (ColCount > IndicatorOffset + 1) then
  begin
    FixCount := Min(FixCount, ColCount - 1);
    inherited FixedCols := FixCount;
    for I := 1 to Min(FixedCols, ColCount - 1) do
      TabStops[I + IndicatorOffset - 1] := False;
  end;
  FFixedCols := FixCount - IndicatorOffset;
end;

function TJvDBGrid.GetFixedCols: Integer;
begin
  if DataLink.Active then
    Result := inherited FixedCols - IndicatorOffset
  else
    Result := FFixedCols;
end;

function TJvDBGrid.CalcLeftColumn: Integer;
begin
  Result := FixedCols + IndicatorOffset;
  while (Result < ColCount) and (ColWidths[Result] <= 0) do
    Inc(Result);
end;

procedure TJvDBGrid.KeyDown(var Key: Word; Shift: TShiftState);
var
  KeyDownEvent: TKeyEvent;

  procedure ClearSelections;
  begin
    if FMultiSelect then
    begin
      if FClearSelection then
        SelectedRows.Clear;
      FSelecting := False;
    end;
  end;

  procedure DoSelection(Select: Boolean; Direction: Integer);
  var
    AddAfter: Boolean;
  begin
    AddAfter := False;
    BeginUpdate;
    try
      if MultiSelect and DataLink.Active then
        if Select and (Shift * KeyboardShiftStates = [ssShift]) then
        begin
          if not FSelecting then
          begin
            {$IFDEF CLR}
            FSelectionAnchor := GetNonPublicProperty(SelectedRows, 'CurrentRow') as TBookmarkStr;
            {$ELSE}
            FSelectionAnchor := TBookmarks(SelectedRows).CurrentRow;
            {$ENDIF CLR}
            SelectedRows.CurrentRowSelected := True;
            FSelecting := True;
            AddAfter := True;
          end
          else
          begin
            {$IFDEF CLR}
            AddAfter := DataSource.DataSet.CompareBookmarkStr(GetNonPublicProperty(SelectedRows, 'CurrentRow') as TBookmarkStr,
              FSelectionAnchor) <> -Direction;
            if AddAfter then
              SelectedRows.CurrentRowSelected := False;
            {$ELSE}
            with TBookmarks(SelectedRows) do
            begin
              AddAfter := Compare(CurrentRow, FSelectionAnchor) <> -Direction;
              if not AddAfter then
                CurrentRowSelected := False;
            end;
            {$ENDIF CLR}
          end;
        end
        else
          ClearSelections;
      if Direction <> 0 then
        DataLink.DataSet.MoveBy(Direction);
      if AddAfter then
        SelectedRows.CurrentRowSelected := True;
    finally
      EndUpdate;
    end;
  end;

  procedure NextRow(Select: Boolean);
  begin
    with DataLink.DataSet do
    begin
      DoSelection(Select, 1);
      if AutoAppend and Eof and CanModify and (not ReadOnly) and (dgEditing in Options) then
        Append;
    end;
  end;

  procedure PriorRow(Select: Boolean);
  begin
    DoSelection(Select, -1);
  end;

  procedure CheckTab(GoForward: Boolean);
  var
    ACol, Original: Integer;
  begin
    ACol := Col;
    Original := ACol;
    if MultiSelect and DataLink.Active then
      while True do
      begin
        if GoForward then
          Inc(ACol)
        else
          Dec(ACol);
        if ACol >= ColCount then
        begin
          ClearSelections;
          ACol := IndicatorOffset;
        end
        else
        if ACol < IndicatorOffset then
        begin
          ClearSelections;
          ACol := ColCount;
        end;
        if ACol = Original then
          Exit;
        if TabStops[ACol] then
          Exit;
      end;
  end;

  function DeletePrompt: Boolean;
  var
    S: string;
  begin
    if SelectedRows.Count > 1 then
      S := SDeleteMultipleRecordsQuestion
    else
      S := SDeleteRecordQuestion;
    Result := not (dgConfirmDelete in Options) or
      (MessageDlg(S, mtConfirmation, [mbYes, mbNo], 0) = mrYes);
  end;

begin
  KeyDownEvent := OnKeyDown;
  if Assigned(KeyDownEvent) then
    KeyDownEvent(Self, Key, Shift);
  if not DataLink.Active or not CanGridAcceptKey(Key, Shift) then
    Exit;
  with DataLink.DataSet do
    if ssCtrl in Shift then
    begin
      if Key in [VK_UP, VK_PRIOR, VK_DOWN, VK_NEXT, VK_HOME, VK_END] then
        ClearSelections;
      case Key of
        VK_LEFT:
          if FixedCols > 0 then
          begin
            SelectedIndex := CalcLeftColumn - IndicatorOffset;
            Exit;
          end;
        VK_DELETE:
          if CanDelete and not ReadOnly and CanModify and not
            IsDataSetEmpty(DataLink.DataSet) then
          begin
            if DeletePrompt then
            begin
              if SelectedRows.Count > 0 then
                SelectedRows.Delete
              else
                Delete;
            end;
            Exit;
          end
          else
          begin
            // Mantis 4231: Do not pass delete to inherited grid as it would
            // allow deleting the row while having CanDelete set to False. 
            Exit;
          end;
      end;
    end
    else
    begin
      case Key of
        VK_LEFT:
          if (FixedCols > 0) and not (dgRowSelect in Options) then
            if SelectedIndex <= CalcLeftColumn - IndicatorOffset then
              Exit;
        VK_HOME:
          if (FixedCols > 0) and (ColCount <> IndicatorOffset + 1) and
            not (dgRowSelect in Options) then
          begin
            SelectedIndex := CalcLeftColumn - IndicatorOffset;
            Exit;
          end;
      end;
      if DataLink.DataSet.State <> dsInsert then
        case Key of
          VK_UP:
            begin
              PriorRow(True);
              Exit;
            end;
          VK_DOWN:
            begin
              NextRow(True);
              Exit;
            end;
        end;
      if ((Key in [VK_LEFT, VK_RIGHT]) and (dgRowSelect in Options)) or
        ((Key in [VK_HOME, VK_END]) and ((ColCount = IndicatorOffset + 1) or
        (dgRowSelect in Options))) or (Key in [VK_ESCAPE, VK_NEXT, VK_PRIOR]) or
        ((Key = VK_INSERT) and CanModify and (not ReadOnly) and (dgEditing in Options)) then
        ClearSelections
      else
      if (Key = VK_TAB) and not (ssAlt in Shift) then
        CheckTab(not (ssShift in Shift));
    end;

  OnKeyDown := nil;
  try
    inherited KeyDown(Key, Shift);
  finally
    OnKeyDown := KeyDownEvent;
  end;
end;

procedure TJvDBGrid.SetShowGlyphs(Value: Boolean);
begin
  if FShowGlyphs <> Value then
  begin
    FShowGlyphs := Value;
    Invalidate;
  end;
end;

procedure TJvDBGrid.SetAutoSizeRows(Value: Boolean);
begin
  if FAutoSizeRows <> Value then
  begin
    FAutoSizeRows := Value;
    if FAutoSizeRows then
    begin
      RowResize := False;
      LayoutChanged; // Recalculate DefaultRowHeight
    end;
  end;
end;

procedure TJvDBGrid.SetRowsHeight(Value: Integer);
begin
  if (DefaultRowHeight <> Value) and not AutoSizeRows then
  begin
    FRowsHeight := Value;
    DefaultRowHeight := Value;
    if dgTitles in Options then
      RowHeights[0] := TitleRowHeight;
    if HandleAllocated then
      Perform(WM_SIZE, SIZE_RESTORED, MakeLong(ClientWidth, ClientHeight));
  end
  else
    FRowsHeight := DefaultRowHeight;
end;

procedure TJvDBGrid.SetTitleRowHeight(Value: Integer);
begin
  if (dgTitles in Options) and (RowHeights[0] <> Value) and not AutoSizeRows then
  begin
    FTitleRowHeight := Value;
    RowHeights[0] := Value;
    if HandleAllocated then
      Perform(WM_SIZE, SIZE_RESTORED, MakeLong(ClientWidth, ClientHeight));
  end
  else
    FTitleRowHeight := RowHeights[0];
end;

procedure TJvDBGrid.RowHeightsChanged;
var
  RowIdx,
  FirstRow: Integer;
begin
  if DefaultRowHeight <> RowsHeight then
    SetRowsHeight(RowsHeight);
  if RowHeights[0] <> TitleRowHeight then
    SetTitleRowHeight(TitleRowHeight);

  if RowResize then
  begin
    if dgTitles in Options then
      FirstRow := 1
    else
      FirstRow := 0;
    for RowIdx := FirstRow to VisibleRowCount + 1 do
      if RowHeights[RowIdx] <> RowsHeight then
      begin
        SetRowsHeight(RowHeights[RowIdx]);
        Break;
      end;
  end;

  inherited RowHeightsChanged;
end;

function TJvDBGrid.GetDataLink: TDataLink;
begin
  Result := DataLink;
end;

procedure TJvDBGrid.SetRowResize(Value: Boolean);
begin
  if FRowResize <> Value then
  begin
    if AutoSizeRows then
      FRowResize := False
    else
      FRowResize := Value;
    SetOptions(Options);
  end;
end;

function TJvDBGrid.GetOptions: TDBGridOptions;
begin
  Result := inherited Options;
  if FMultiSelect then
    Result := Result + [dgMultiSelect]
  else
    Result := Result - [dgMultiSelect];

  if FAlwaysShowEditor then
    Result := Result + [dgAlwaysShowEditor]
  else
    Result := Result - [dgAlwaysShowEditor];
end;

procedure TJvDBGrid.SetOptions(Value: TDBGridOptions);
var
  NewOptions: TGridOptions;
  {$IFDEF CLR}
  OptionsProp: PropertyInfo;
  {$ENDIF CLR}
begin
  { The AlwaysShowEditor option is not compatible with the custom inplace edit
    controls. But if the EditorMode is set to True in ColEnter() it emulates the
    AlwaysShowEditor option. }
  inherited Options := Value - [dgMultiSelect, dgAlwaysShowEditor];
  FAlwaysShowEditor := dgAlwaysShowEditor in Value;

  {$IFDEF CLR}
  { TJvDBGrid - TDBGrid - TCustomGrid }
  OptionsProp := Self.GetType.BaseType.BaseType.GetProperty('Options', BindingFlags.NonPublic or BindingFlags.Instance);
  NewOptions := OptionsProp.GetValue(Self, []) as TGridOptions;
  {$ELSE}
  NewOptions := TDrawGrid(Self).Options;
  {$ENDIF CLR}
  {
  if FTitleButtons then
  begin
    TDrawGrid(Self).Options := NewOptions + [goFixedHorzLine, goFixedVertLine];
  end
  else
  }
  begin
    if RowResize then
      Include(NewOptions, goRowSizing)
    else
      Exclude(NewOptions, goRowSizing);
    if not (dgColLines in Value) then
      NewOptions := NewOptions - [goFixedVertLine];
    if not (dgRowLines in Value) then
      NewOptions := NewOptions - [goFixedHorzLine];
    {$IFDEF CLR}
    OptionsProp.SetValue(Self, TObject(NewOptions), []); 
    {$ELSE}
    TDrawGrid(Self).Options := NewOptions;
    {$ENDIF CLR}
  end;
  SetMultiSelect(dgMultiSelect in Value);
end;

function TJvDBGrid.DoEraseBackground(Canvas: TCanvas; Param: Integer): Boolean;
var
  R: TRect;
  Size: TSize;
begin
  { Fill the area between the two scroll bars. }
  Size.cx := GetSystemMetrics(SM_CXVSCROLL);
  Size.cy := GetSystemMetrics(SM_CYHSCROLL);
  R := Bounds(Width - Size.cx, Height - Size.cy, Size.cx, Size.cy);
  Canvas.Brush.Color := Color;
  Canvas.FillRect(R);

  Result := True;
end;

procedure TJvDBGrid.Paint;
begin
  {$IFDEF JVCLThemesEnabled}
  if UseXPThemes and ThemeServices.ThemesEnabled then
  begin
    // reset the inherited options but remove the goFixedVertLine and goFixedHorzLine values
    // as that causes the titles and indicator panels to have a black border
    TStringGrid(Self).Options := TStringGrid(Self).Options - [goFixedVertLine];
    TStringGrid(Self).Options := TStringGrid(Self).Options - [goFixedHorzLine];
  end;
  {$ENDIF JVCLThemesEnabled}
  inherited Paint;
  if not (csDesigning in ComponentState) and
    (dgRowSelect in Options) and DefaultDrawing and Focused then
  begin
    Canvas.Font.Color := clWindowText;
    with Selection do
      DrawFocusRect(Canvas.Handle, BoxRect(Left, Top, Right, Bottom));
  end;
end;

procedure TJvDBGrid.SetTitleButtons(Value: Boolean);
begin
  if FTitleButtons <> Value then
  begin
    FTitleButtons := Value;
    Invalidate;
    SetOptions(Options);
  end;
end;

procedure TJvDBGrid.SetMultiSelect(Value: Boolean);
begin
  if FMultiSelect <> Value then
  begin
    FMultiSelect := Value;
    if not Value then
      SelectedRows.Clear;
  end;
end;

function TJvDBGrid.GetStorage: TJvFormPlacement;
begin
  Result := FIniLink.Storage;
end;

procedure TJvDBGrid.SetStorage(Value: TJvFormPlacement);
begin
  FIniLink.Storage := Value;
end;

function TJvDBGrid.AcquireFocus: Boolean;
begin
  Result := True;
  if FAcquireFocus and CanFocus and not (csDesigning in ComponentState) then
  begin
    SetFocus;
    Result := Focused or ((InplaceEditor <> nil) and InplaceEditor.Focused) or
                         ((FCurrentControl <> nil) and FCurrentControl.Focused);
  end;
end;

function TJvDBGrid.CanEditShow: Boolean;

  function UseDefaultEditor: Boolean;
  const
    ude_DEFAULT_EDITOR = 0;
    ude_BOOLEAN_EDITOR = 1;
    ude_CUSTOM_EDITOR = 2;
  var
    F: TField;
    Editor: Shortint;
    Control: TJvDBGridControl;
    EditControl: TWinControl;

    function IsReadOnlyField: Boolean;
    begin
      Result := ReadOnly or Columns[SelectedIndex].ReadOnly or F.ReadOnly or
        not F.DataSet.CanModify;
    end;

  begin
    // Is there an editor for the selected field ?
    F := SelectedField;
    Control := FControls.ControlByField(F.FieldName);
    if Assigned(Control) then
      Editor := ude_CUSTOM_EDITOR
    else
    if EditWithBoolBox(F) then
      Editor := ude_BOOLEAN_EDITOR
    else
    begin
      Editor := ude_DEFAULT_EDITOR;

      // The default editor cannot modify a binary or memo field
      if (F.DataType in [ftUnknown, ftBytes, ftVarBytes, ftAutoInc, ftBlob,
        ftMemo, ftFmtMemo, ftGraphic, ftTypedBinary, ftDBaseOle, ftParadoxOle,
        ftCursor, ftADT, ftReference, ftDataSet, ftOraBlob, ftOraClob]) then
      begin
        Result := False;
        HideCurrentControl;
        HideEditor;
        Exit;
      end;
    end;

    // There is an editor, so we trigger the OnShowEditor event
    Result := True;
    if Assigned(OnShowEditor) and
      not (Assigned(InplaceEditor) and InplaceEditor.Visible) then
    begin
      // This event can be triggered twice with the default editor because of the
      // two successive calls to CanEditShow in the UpdateEdit function of Grids.pas
      OnShowEditor(Self, F, Result);
      if not Result then
      begin
        HideCurrentControl;
        HideEditor;
        Exit;
      end;
    end;

    // Is it a customized editor ?
    if Editor = ude_CUSTOM_EDITOR then
    begin
      Result := False;
      HideEditor;
      EditControl := TWinControl(Owner.FindComponent(Control.ControlName));
      if not Assigned(EditControl) then
      begin
        Control.FieldName := '';
        raise EJVCLDbGridException.CreateRes({$IFNDEF CLR}@{$ENDIF}RsEJvDBGridControlPropertyNotAssigned);
      end;
      if IsPublishedProp(EditControl, 'ReadOnly') then
      begin
        SetOrdProp(EditControl, 'ReadOnly', Ord(IsReadOnlyField));
        PlaceControl(EditControl, Col, Row);
      end
      else
      if IsReadOnlyField then
        HideCurrentControl
      else
        PlaceControl(EditControl, Col, Row);
    end
    else
    if Editor = ude_BOOLEAN_EDITOR then
    begin
      // Boolean editor
      Result := False;
      HideCurrentControl;
      HideEditor;
      if not IsReadOnlyField then
        FBooleanFieldToEdit := F;
    end
    else
      // Default editor
      HideCurrentControl;
  end;

begin
  Result := False;
  if (inherited CanEditShow) and Assigned(SelectedField) and
    (SelectedIndex >= 0) and (SelectedIndex < Columns.Count) then
  begin
    FBooleanFieldToEdit := nil;
    Result := UseDefaultEditor;
  end
  else
  begin
    if not (Assigned(InplaceEditor) and InplaceEditor.Visible) then
      HideEditor;
  end;
end;

procedure TJvDBGrid.GetCellProps(Field: TField; AFont: TFont;
  var Background: TColor; Highlight: Boolean);

  function IsAfterFixedCols: Boolean;
  var
    I: Integer;
  begin
    Result := True;
    for I := 0 to FixedCols - 1 do
      if Assigned(Field) and Assigned(Columns.Items[I]) and (Columns.Items[I].FieldName = Field.FieldName) then
      begin
        Result := False;
        Break;
      end;
  end;

begin
  if IsAfterFixedCols and (FCurrentDrawRow >= FixedRows) then
  begin
    if Odd(FCurrentDrawRow + FixedRows) then
    begin
      if (FAlternateRowColor <> clNone) and (FAlternateRowColor <> Color) then
        Background := AlternateRowColor;
      if FAlternateRowFontColor <> clNone then
        AFont.Color := AlternateRowFontColor;
    end;
  end
  else
    Background := FixedColor;

  if Highlight then
  begin
    AFont.Color := clHighlightText;
    Background := clHighlight;
  end;
  if Assigned(FOnGetCellParams) then
    FOnGetCellParams(Self, Field, AFont, Background, Highlight)
  else
  if Assigned(FOnGetCellProps) then
    FOnGetCellProps(Self, Field, AFont, Background);
end;

procedure TJvDBGrid.DoTitleClick(ACol: Longint; AField: TField);
// Fred: This function has a few known bugs, so don't complain about them and use
// JvDBUltimGrid instead if you're looking for an improved sorting function.
const
  cIndexName = 'IndexName';
  cIndexDefs = 'IndexDefs';
  cDirection: array [Boolean] of TSortMarker = (smDown, smUp);
var
  IndexDefs: TIndexDefs;
  LIndexName: string;
  Descending: Boolean;
  IndexFound: Boolean;

  function GetIndexOf(AFieldName: string; var AIndexName: string; var Descending: Boolean): Boolean;
  var
    I: Integer;
    IsDescending: Boolean;

  begin
    Result := False;
    for I := 0 to IndexDefs.Count - 1 do
    begin
      if Pos(AFieldName, IndexDefs[I].Fields) >= 1 then
      begin
        AIndexName := IndexDefs[I].Name; // best match so far
        IsDescending := (ixDescending in IndexDefs[I].Options);
        Result := True;
        if Descending <> IsDescending then
          // we've found an index that is the opposite direction of the previous one, so we return now
        begin
          Descending := IsDescending;
          Exit;
        end;
      end;
      // if we get here and Result is True, it means we've found a matching index but it
      // might be the same as the previous one...
    end;
  end;

begin
  IndexFound := False;

  if AutoSort and IsPublishedProp(DataSource.DataSet, cIndexDefs) and
    IsPublishedProp(DataSource.DataSet, cIndexName) then
    IndexDefs := TIndexDefs(GetObjectProp(DataSource.DataSet, cIndexDefs))
  else
    IndexDefs := nil;
  if Assigned(IndexDefs) and Assigned(AField) then
  begin
    Descending := SortMarker = smUp;
    if GetIndexOf(AField.FieldName, LIndexName, Descending) then
    begin
      IndexFound := True;
      SortedField := AField.FieldName;
      SortMarker := cDirection[Descending];
      try
        SetStrProp(DataSource.DataSet, cIndexName, LIndexName);
      except
      end;
    end;
  end;
  //--------------------------------------------------------------------------
  // FBC: 2004-02-18
  // Following code handles the sortmarker if no Index is found.
  // the actual data-sorting must be implemented by the user in
  // event OnTitleBtnClick. Of course, we need a field (Mantis 3845)
  //--------------------------------------------------------------------------
  if AutoSort and not IndexFound and Assigned(AField) then
  begin
    if SortedField = AField.FieldName then
    begin
      case Self.SortMarker of
        smUp:
          Self.SortMarker := smDown;
        smDown:
          Self.SortMarker := smUp;
      end;
    end
    else
    begin
      SortedField := AField.FieldName;
      Self.SortMarker := smUp;
    end;
  end;
  if Assigned(FOnTitleBtnClick) then
    FOnTitleBtnClick(Self, ACol, AField);
end;

procedure TJvDBGrid.CheckTitleButton(ACol, ARow: Longint; var Enabled: Boolean);
var
  Field: TField;
begin
  if (ACol >= 0) and (ACol < Columns.Count) then
  begin
    if Assigned(FOnCheckButton) then
    begin
      Field := Columns[ACol].Field;
      if ColumnAtDepth(Columns[ACol], ARow) <> nil then
        Field := ColumnAtDepth(Columns[ACol], ARow).Field;
      FOnCheckButton(Self, ACol, Field, Enabled);
    end;
  end
  else
    Enabled := False;
end;

procedure TJvDBGrid.DisableScroll;
begin
  Inc(FDisableCount);
end;

type
  TGridDataLinkAccessProtected = class(TGridDataLink);

procedure TJvDBGrid.EnableScroll;
begin
  if FDisableCount <> 0 then
  begin
    Dec(FDisableCount);
    if FDisableCount = 0 then
      {$IFDEF CLR}
      InvokeNonPublicMethod(DataLink, 'DataSetScrolled', [0]);
      {$ELSE}
      TGridDataLinkAccessProtected(DataLink).DataSetScrolled(0);
      {$ENDIF CLR}
  end;
end;

function TJvDBGrid.ScrollDisabled: Boolean;
begin
  Result := FDisableCount <> 0;
end;

procedure TJvDBGrid.Scroll(Distance: Integer);
begin
  if FDisableCount = 0 then
  begin
    inherited Scroll(Distance);
    if ((AlternateRowColor <> clNone) and (AlternateRowColor <> Color)) or
       ((AlternateRowFontColor <> clNone) and (AlternateRowFontColor <> Font.Color)) then
      Invalidate;
  end;
end;

function TJvDBGrid.DoMouseWheelDown(Shift: TShiftState; MousePos: TPoint): Boolean;
var
  Distance: Integer;
begin
  Result := False;
  if Assigned(OnMouseWheelDown) then
    OnMouseWheelDown(Self, Shift, MousePos, Result);
  if not Result then
  begin
    if not AcquireFocus then
      Exit;
    if ssCtrl in Shift then
      Distance := VisibleRowCount - 1
    else
      Distance := 1;
    if DataLink.Active then
      Result := DataLink.DataSet.MoveBy(Distance) <> 0;
  end;
end;

function TJvDBGrid.DoMouseWheelUp(Shift: TShiftState; MousePos: TPoint): Boolean;
var
  Distance: Integer;
begin
  Result := False;
  if Assigned(OnMouseWheelUp) then
    OnMouseWheelUp(Self, Shift, MousePos, Result);
  if not Result then
  begin
    if not AcquireFocus then
      Exit;
    if Shift * KeyboardShiftStates = [ssCtrl] then
      Distance := VisibleRowCount - 1
    else
      Distance := 1;
    if DataLink.Active then
      Result := DataLink.DataSet.MoveBy(-Distance) <> 0;
  end;
end;

{$IFDEF COMPILER6_UP}
procedure TJvDBGrid.EditChanged(Sender: TObject);
begin
  if Assigned(FOnEditChange) then
    FOnEditChange(Self);
end;
{$ENDIF COMPILER6_UP}

procedure TJvDBGrid.GridInvalidateRow(Row: Longint);
var
  I: Longint;
begin
  for I := 0 to ColCount - 1 do
    InvalidateCell(I, Row);
end;

procedure TJvDBGrid.TopLeftChanged;
begin
  if (dgRowSelect in Options) and DefaultDrawing then
    GridInvalidateRow(Self.Row);
  inherited TopLeftChanged;
  if FTracking then
    StopTracking;
  if Assigned(FOnTopLeftChanged) then
    FOnTopLeftChanged(Self);

  NotifyLayoutChange(lcTopLeftChanged);
end;

procedure TJvDBGrid.StopTracking;
begin
  if FTracking or FSwapButtons then
  begin
    TrackButton(-1, -1);
    FTracking := False;
    MouseCapture := False;
  end;
end;

procedure TJvDBGrid.TrackButton(X, Y: Integer);
var
  Cell: TGridCoord;
  NewPressed: Boolean;
  I, Offset: Integer;
begin
  Cell := MouseCoord(X, Y);
  Offset := TitleOffset;
  NewPressed := Windows.PtInRect(Rect(0, 0, ClientWidth, ClientHeight), {Types.} Point(X, Y)) and
    (FPressedCol = GetMasterColumn(Cell.X, Cell.Y)) and (Cell.Y < Offset);
  if FPressed <> NewPressed then
  begin
    FPressed := NewPressed;
    for I := 0 to Offset - 1 do
      GridInvalidateRow(I);
  end;
end;

procedure TJvDBGrid.MouseDown(Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
var
  Cell, LastCell: TGridCoord;
  MouseDownEvent: TMouseEvent;
  EnableClick: Boolean;
  CursorPos: TPoint;
  lLastSelected, lNewSelected: TBookmarkStr;
  lCompare: Integer;
begin
  if not AcquireFocus then
    Exit;
  if (ssDouble in Shift) and (Button = mbLeft) then
  begin
    DblClick;
    Exit;
  end;
  FAcquireFocus := False;
  try
    { XP Theming }
    {$IFDEF JVCLThemesEnabled}
    if not (csDesigning in ComponentState) and UseXPThemes and ThemeServices.ThemesEnabled then
    begin
      FPaintInfo.ColSizing := Sizing(X, Y);
      if not FPaintInfo.ColSizing then
      begin
        FPaintInfo.ColPressedIdx := -1;
        FPaintInfo.ColPressed := False;
        if AllowTitleClick then
          FPaintInfo.MouseInCol := -1;
        Cell := MouseCoord(X, Y);
        if (Button = mbLeft) and (Cell.X >= IndicatorOffset) and (Cell.Y >= 0) and AllowTitleClick then
        begin
          FPaintInfo.ColPressed := Cell.Y < TitleOffset;
          if FPaintInfo.ColPressed then
            FPaintInfo.ColPressedIdx := Columns[RawToDataColumn(Cell.X)].Index + ColumnOffset;
          if ValidCell(FCell) then
            InvalidateCell(FCell.X, FCell.Y);
          FCell := Cell;
        end;
      end;
    end;
    {$ENDIF JVCLThemesEnabled}

    if Sizing(X, Y) then
      inherited MouseDown(Button, Shift, X, Y)
    else
    begin
      Cell := MouseCoord(X, Y);
      LastCell.X := Col;
      LastCell.Y := Row;

      if (Button = mbRight) and
        (dgTitles in Options) and (dgIndicator in Options) and
        (Cell.X = 0) and (Cell.Y = 0) then
      begin
        if (FTitleArrow and Assigned(FOnTitleArrowMenuEvent)) then
          FOnTitleArrowMenuEvent(Self);

        // Display TitlePopup if it exists
        if Assigned(FTitlePopup) then
        begin
          GetCursorPos(CursorPos);
          FTitlePopup.PopupComponent := Self;
          FTitlePopup.Popup(CursorPos.X, CursorPos.Y);
        end;
        Exit;
      end;

      if (DragKind = dkDock) and (Cell.X < IndicatorOffset) and
        (Cell.Y < TitleOffset) and not (csDesigning in ComponentState) then
      begin
        BeginDrag(False);
        Exit;
      end;
      if FTitleButtons and (DataLink <> nil) and DataLink.Active and
        (Cell.Y < TitleOffset) and (Cell.X >= IndicatorOffset) and
        not (csDesigning in ComponentState) then
      begin
        if ((dgColumnResize in Options) or (csDesigning in ComponentState)) and (Button = mbRight) then
        begin
          Button := mbLeft;
          FSwapButtons := True;
          MouseCapture := True;
          FPressedCol := GetMasterColumn(Cell.X, Cell.Y);
          TrackButton(X, Y);
        end
        else
        if Button = mbLeft then
        begin
          EnableClick := True;
          CheckTitleButton(Cell.X - IndicatorOffset, Cell.Y, EnableClick);
          if EnableClick then
          begin
            MouseCapture := True;
            FTracking := True;
            FPressedCol := GetMasterColumn(Cell.X, Cell.Y);
            TrackButton(X, Y);
          end
          else
          if FBeepOnError then
            SysUtils.Beep;
          Exit;
        end;
      end;
      if (Cell.X < FixedCols + IndicatorOffset) and DataLink.Active then
      begin
        if dgIndicator in Options then
          inherited MouseDown(Button, Shift, 1, Y)
        else
        if Cell.Y >= TitleOffset then
          if Cell.Y - Row <> 0 then
            DataLink.DataSet.MoveBy(Cell.Y - Row);
      end
      else
      begin
        //-------------------------------------------------------------------------------
        // Prevents the grid from going back to the first column when dgRowSelect is True
        // Does not work if there's no indicator column
        //-------------------------------------------------------------------------------
        if (dgRowSelect in Options) and (Cell.Y >= TitleOffset) then
          inherited MouseDown(Button, Shift, 1, Y)
        else
          inherited MouseDown(Button, Shift, X, Y);
        if (Col = LastCell.X) and (Row <> LastCell.Y) then
        begin
          { ColEnter is not invoked when switching between rows staying in the
            same column. }
          if FAlwaysShowEditor and not EditorMode then
            ShowEditor;
        end;
      end;
      MouseDownEvent := OnMouseDown;
      if Assigned(MouseDownEvent) then
        MouseDownEvent(Self, Button, Shift, X, Y);
      if not (((csDesigning in ComponentState) or (dgColumnResize in Options)) and
        (Cell.Y < TitleOffset)) and (Button = mbLeft) then
      begin
        if MultiSelect and DataLink.Active then
          with SelectedRows do
          begin
            FSelecting := False;
            if Shift * KeyboardShiftStates = [ssCtrl] then
              CurrentRowSelected := not CurrentRowSelected
            else
            begin
              if (Shift * KeyboardShiftStates = [ssShift]) and (Count > 0) then
              begin
                lLastSelected := Items[Count - 1];
                CurrentRowSelected := not CurrentRowSelected;
                if CurrentRowSelected then
                begin
                  with DataLink.DataSet do
                  begin
                    DisableControls;
                    try
                      lNewSelected := Bookmark;
                      {$IFDEF CLR}
                      lCompare := CompareBookmarkStr(lNewSelected, lLastSelected);
                      {$ELSE}
                      lCompare := CompareBookmarks(Pointer(lNewSelected), Pointer(lLastSelected));
                      {$ENDIF CLR}
                      if lCompare > 0 then
                      begin
                        {$IFDEF CLR}
                        Bookmark := lLastSelected;
                        {$ELSE}
                        GotoBookmark(Pointer(lLastSelected));
                        {$ENDIF CLR}
                        Next;
                        while not (CurrentRowSelected and (Bookmark = lNewSelected)) do
                        begin
                          CurrentRowSelected := True;
                          Next;
                        end;
                      end
                      else
                      if lCompare < 0 then
                      begin
                        {$IFDEF CLR}
                        Bookmark := lLastSelected;
                        {$ELSE}
                        GotoBookmark(Pointer(lLastSelected));
                        {$ENDIF CLR}
                        Prior;
                        while not (CurrentRowSelected and (Bookmark = lNewSelected)) do
                        begin
                          CurrentRowSelected := True;
                          Prior;
                        end;
                      end;
                    finally
                      EnableControls;
                    end;
                  end;
                end;
              end
              else
              begin
                Clear;
                if FClearSelection then
                  CurrentRowSelected := True;
              end;
            end;
          end;
      end;
    end;
  finally
    FAcquireFocus := True;
  end;
end;

procedure TJvDBGrid.MouseMove(Shift: TShiftState; X, Y: Integer);
{$IFDEF JVCLThemesEnabled}
var
  Cell: TGridCoord;
  MouseInCol: Integer;
{$ENDIF JVCLThemesEnabled}
begin
  { XP Theming }
  {$IFDEF JVCLThemesEnabled}
  if not (csDesigning in ComponentState) and UseXPThemes and ThemeServices.ThemesEnabled then
  begin
    if not FPaintInfo.ColSizing and not FPaintInfo.ColMoving then
    begin
      FPaintInfo.MouseInCol := -1;
      Cell := MouseCoord(X, Y);
      if (Cell.X >= IndicatorOffset) and (Cell.Y >= 0) then
      begin
        if (Cell.Y < TitleOffset) then
        begin
          MouseInCol := Columns[RawToDataColumn(Cell.X)].Index + ColumnOffset;
          if MouseInCol <> FPaintInfo.MouseInCol then
          begin
            InvalidateCell(Cell.X, Cell.Y);
            FPaintInfo.MouseInCol := MouseInCol;
          end;
        end
      end;
      if ValidCell(FCell) then
        InvalidateCell(FCell.X, FCell.Y);
      FCell := Cell;
    end;
  end;
  {$ENDIF JVCLThemesEnabled}

  if FTracking and not FSwapButtons then
    TrackButton(X, Y);
  inherited MouseMove(Shift, X, Y);
end;

procedure TJvDBGrid.MouseUp(Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
var
  Cell: TGridCoord;
  ACol: Longint;
  DoClick: Boolean;
  ALeftCol: Integer;
begin
  Cell := MouseCoord(X, Y);
  if FTracking and (FPressedCol <> nil) then
  begin
    DoClick := PtInRect(Rect(0, 0, ClientWidth, ClientHeight), {Types.} Point(X, Y)) and
      (Cell.Y < TitleOffset) and
      (FPressedCol = GetMasterColumn(Cell.X, Cell.Y));
    StopTracking;
    if DoClick then
    begin
      ACol := Cell.X;
      if dgIndicator in Options then
        Dec(ACol);
      if (DataLink <> nil) and DataLink.Active and (ACol >= 0) and
        (ACol < Columns.Count) then
        DoTitleClick(FPressedCol.Index, FPressedCol.Field);
    end;
  end
  else
  if FSwapButtons then
  begin
    StopTracking;
    FSwapButtons := False;
    MouseCapture := False;
    if Button = mbRight then
      Button := mbLeft;
  end;
  if (Button = mbLeft) and (FGridState = gsColSizing) and
    (FSizingIndex + Byte(not (dgIndicator in Options)) <= FixedCols) then
  begin
    ColWidths[FSizingIndex] := GetMinColWidth(X - FSizingOfs - CellRect(FSizingIndex, 0).Left);
    FGridState := gsNormal;
  end;

  if FTitleArrow and (Button = mbLeft) and
    (dgTitles in Options) and (dgIndicator in Options) and
    (Cell.X = 0) and (Cell.Y = 0) and (Columns.Count > 0) then
    ShowSelectColumnClick; // Selection of columns

  if (Button = mbLeft) and (FGridState = gsColSizing) then
  begin
    ALeftCol := LeftCol;
    inherited MouseUp(Button, Shift, X, Y);
    if (dgRowSelect in Options) then
      LeftCol := ALeftCol;
    if Assigned(OnColumnResized) then
      OnColumnResized(Self, FSizingIndex + Byte(not (dgIndicator in Options)) - 1,
        ColWidths[FSizingIndex]);
  end
  else
    inherited MouseUp(Button, Shift, X, Y);
  DoAutoSizeColumns;

  { XP Theming }
  {$IFDEF JVCLThemesEnabled}
  if UseXPThemes and ThemeServices.ThemesEnabled then
  begin
    FPaintInfo.ColSizing := False;
    FPaintInfo.ColMoving := False;
    FPaintInfo.ColPressedIdx := -1;
    Invalidate;
  end;
  {$ENDIF JVCLThemesEnabled}
end;

procedure TJvDBGrid.WMRButtonUp(var Msg: TWMMouse);
begin
  if not (FGridState in [gsColMoving, gsRowMoving]) then
    inherited
  else
  if not (csNoStdEvents in ControlStyle) then
    with Msg do
      MouseUp(mbRight, KeysToShiftState(Keys), XPos, YPos);
end;

procedure TJvDBGrid.WMCancelMode(var Msg: TMessage);
begin
  StopTracking;
  inherited;
end;

type
  TWinControlAccessProtected = class(TWinControl);

function TJvDBGrid.DoKeyPress(var Msg: TWMChar): Boolean;
var
  Form: TCustomForm;
  Ch: Char;
begin
  Result := True;
  Form := GetParentForm(Self);
  if Form <> nil then
    {$IFDEF CLR}
    if Form.KeyPreview and Boolean(InvokeNonPublicMethod(Form, 'DoKeyPress', [Msg])) then
    {$ELSE}
    if Form.KeyPreview and TWinControlAccessProtected(Form).DoKeyPress(Msg) then
    {$ENDIF CLR}
      Exit;

  with Msg do
  begin
    if Assigned(OnKeyPress) then
    begin
      Ch := Char(CharCode);
      OnKeyPress(Self, Ch);
      CharCode := Word(Ch);
    end;
    if CharCode = 0 then
      Exit;
  end;
  Result := False;
end;

procedure TJvDBGrid.WMChar(var Msg: TWMChar);
begin
  if Assigned(SelectedField) and EditWithBoolBox(SelectedField) and
    (Char(Msg.CharCode) in [Backspace, #32..#255]) then
  begin
    if not DoKeyPress(Msg) then
      case Char(Msg.CharCode) of
        #32:
        begin
          ShowEditor;
          ChangeBoolean(JvGridBool_INVERT);
        end;
        Backspace, '0', '-':
        begin
          ShowEditor;
          ChangeBoolean(JvGridBool_UNCHECK);
        end;
        '1', '+':
        begin
          ShowEditor;
          ChangeBoolean(JvGridBool_CHECK);
        end;
      end;
  end
  else
  begin
    inherited;

    if Assigned(FCurrentControl) then
    begin
      if FCurrentControl.Visible then
        PostMessage(FCurrentControl.Handle, WM_CHAR, Msg.CharCode, Msg.KeyData);
    end
    else
      if InplaceEditor = nil then
        DoKeyPress(Msg); // This is needed to trigger an onKeyPressed event when the
                         // default editor hasn't been created because the data type
                         // of the selected field is binary or memo.
  end;
end;

procedure TJvDBGrid.KeyPress(var Key: Char);
var
  lWord: string;
  lMasterField: TField;
  I, deb: Integer;
  Found: Boolean;

  procedure CharsToFind;
  begin
    if Pos(AnsiUpperCase(FWord), AnsiUpperCase(InplaceEditor.EditText)) <> 1 then
      FWord := '';
    if Key = Backspace then
      if (FWord = '') or (Length(FWord) = 1) then
      begin
        lWord := '';
        FWord := '';
      end
      else
        lWord := Copy(FWord, 1, Length(FWord) - 1)
    else
      lWord := FWord + Key;
  end;

begin
  if (Key = Cr) and PostOnEnterKey and not ReadOnly then
    DataSource.DataSet.CheckBrowseMode;

  if not Assigned(FCurrentControl) then
    inherited KeyPress(Key);

  if EditorMode then
  begin
    // Goal: Allow to go directly into the InplaceEditor when one types the first
    // characters of a word found in the list.
    // Remark: InplaceEditor is protected in TCustomGrid, published in TJvDBGrid.
    if DataSource.DataSet.CanModify and not (ReadOnly or
      Columns[SelectedIndex].ReadOnly or Columns[SelectedIndex].Field.ReadOnly) then
    with Columns[SelectedIndex].Field do
      if (FieldKind = fkLookup) and (Key in CharList) then
      begin
        CharsToFind;
        LookupDataSet.DisableControls;
        try
          try
            if LookupDataSet.Locate(LookupResultField, lWord, [loCaseInsensitive, loPartialKey]) then
            begin
              DataSet.Edit;
              lMasterField := DataSet.FieldByName(KeyFields);
              if lMasterField.CanModify then
              begin
                lMasterField.Value := LookupDataSet.FieldValues[LookupKeyFields];
                FWord := lWord;
                InplaceEditor.SelStart := Length(FWord);
                InplaceEditor.SelLength := Length(InplaceEditor.EditText) - Length(FWord);
              end;
            end;
          except
           { If you attempt to search for a string larger than what the field
             can hold, and exception will be raised. Just trap it. }
          end;
        finally
          LookupDataSet.EnableControls;
        end;
      end
      else
      if FieldKind = fkData then
      begin
        if DataType = ftFloat then
          if Key in ['.', ','] then
            Key := DecimalSeparator{$IFDEF CLR}[1]{$ENDIF};

        if (Key in CharList) and (Columns[SelectedIndex].PickList.Count <> 0) then
        begin
          FWord := InplaceEditor.EditText;
          deb := InplaceEditor.SelStart + InplaceEditor.SelLength;
          if Key = Backspace then
          begin
            if (InplaceEditor.SelLength = 0) then
            begin
              lWord := Copy(FWord, 1, InplaceEditor.SelStart - 1)
                     + Copy(FWord, deb + 1, Length(FWord) - deb + 1);
              deb := InplaceEditor.SelStart - 1;
            end
            else
            begin
              lWord := Copy(FWord, 1, InplaceEditor.SelStart)
                     + Copy(FWord, deb + 1, Length(FWord) - deb);
              deb := InplaceEditor.SelStart;
            end;
          end
          else
          begin
            lWord := Copy(FWord, 1, InplaceEditor.SelStart) + Key
                   + Copy(FWord, deb + 1, Length(FWord) - deb);
            deb := InplaceEditor.SelStart + 1;
          end;

          Found := False;
          with Columns[SelectedIndex].PickList do
            for I := 0 to Count - 1 do
            begin
              if AnsiStartsText(lWord, Strings[I]) then
              begin
                DataSet.Edit;

                InplaceEditor.EditText := Strings[I];
                Columns[SelectedIndex].Field.Text := Strings[I];
                InplaceEditor.SelStart := deb;
                InplaceEditor.SelLength := Length(Text) - deb;
                Found := True;

                Break;
              end;
            end;

          if Found then
            Key := #0;
        end;
      end;
  end
  else
    // This fixes a bug coming from DBGrids.pas when a field is not editable.
    // This ensures that nothing else will process the keys pressed.
    Key := #0;
end;

procedure TJvDBGrid.DefaultDataCellDraw(const Rect: TRect; Field: TField;
  State: TGridDrawState);
begin
  DefaultDrawDataCell(Rect, Field, State);
end;

function TJvDBGrid.GetMasterColumn(ACol, ARow: Longint): TColumn;
begin
  if dgIndicator in Options then
    Dec(ACol, IndicatorOffset);
  if (DataLink <> nil) and DataLink.Active and (ACol >= 0) and (ACol < Columns.Count) then
  begin
    Result := Columns[ACol];
    Result := ColumnAtDepth(Result, ARow);
  end
  else
    Result := nil;
end;

function TJvDBGrid.SortMarkerAssigned(const AFieldName: string): Boolean;
begin
  Result := AnsiSameText(AFieldName, SortedField);
end;

procedure TJvDBGrid.WriteCellText(ARect: TRect; DX, DY: Integer; const Text: string;
  Alignment: TAlignment; ARightToLeft: Boolean; FixCell: Boolean; Options: Integer = 0);
const
  AlignFlags: array [TAlignment] of Integer =
    (DT_LEFT or DT_EXPANDTABS or DT_NOPREFIX,
     DT_RIGHT or DT_EXPANDTABS or DT_NOPREFIX,
     DT_CENTER or DT_EXPANDTABS or DT_NOPREFIX);
  RTL: array [Boolean] of Integer = (0, DT_RTLREADING);
var
  DrawBitmap: TBitmap;
  B, R: TRect;
  Hold, DrawOptions: Integer;

  procedure DrawAText(CellCanvas: TCanvas);
  begin
    with CellCanvas do
    begin
      if Canvas.CanvasOrientation = coRightToLeft then
        ChangeBiDiModeAlignment(Alignment);
      DrawOptions := AlignFlags[Alignment] or RTL[ARightToLeft];
      if Options <> 0 then
        DrawOptions := DrawOptions or Options;
      if WordWrap then
        DrawOptions := DrawOptions or DT_WORDBREAK;
      {$IFDEF JVCLThemesEnabled}
      if not FixCell or not (UseXPThemes and ThemeServices.ThemesEnabled) then
      {$ENDIF JVCLThemesEnabled}
      begin
        if Brush.Style <> bsSolid then
          Brush.Style := bsSolid;
        FillRect(B);
      end;
      SetBkMode(Handle, TRANSPARENT);
      {$IFDEF CLR}
      Windows.DrawText(Handle, Text, Length(Text), R, DrawOptions);
      {$ELSE}
      Windows.DrawText(Handle, PChar(Text), Length(Text), R, DrawOptions);
      {$ENDIF CLR}
    end;
  end;

begin
  if ReduceFlicker {$IFDEF JVCLThemesEnabled} and not (UseXPThemes and ThemeServices.ThemesEnabled) {$ENDIF} then
  begin
    // Use offscreen bitmap to eliminate flicker and
    // brush origin tics in painting / scrolling.
    DrawBitmap := TBitmap.Create;
    try
      DrawBitmap.Canvas.Lock;
      try
        with DrawBitmap, ARect do
        begin
          Width := Max(Width, Right - Left);
          Height := Max(Height, Bottom - Top);
          R := Rect(DX, DY, Right - Left - 1, Bottom - Top - 1);
          B := Rect(0, 0, Right - Left, Bottom - Top);
        end;
        with DrawBitmap.Canvas do
        begin
          Font := Canvas.Font;
          Font.Color := Canvas.Font.Color;
          Brush := Canvas.Brush;
        end;
        DrawAText(DrawBitmap.Canvas);
        if Canvas.CanvasOrientation = coRightToLeft then
        begin
          Hold := ARect.Left;
          ARect.Left := ARect.Right;
          ARect.Right := Hold;
        end;
        Canvas.CopyRect(ARect, DrawBitmap.Canvas, B);
      finally
        DrawBitmap.Canvas.Unlock;
      end;
    finally
      DrawBitmap.Free;
    end;
  end
  else
  begin
    // No offscreen bitmap - The display is faster but flickers
    with ARect do
      R := Rect(Left + DX, Top + DY, Right - 1, Bottom - 1);
    B := ARect;
    DrawAText(Canvas);
  end;
end;

procedure TJvDBGrid.CallDrawCellEvent(ACol, ARow: Longint; ARect: TRect; AState: TGridDrawState);
begin
  inherited DrawCell(ACol, ARow, ARect, AState);
end;

procedure TJvDBGrid.DoDrawCell(ACol, ARow: Longint; ARect: TRect; AState: TGridDrawState);
{$IFDEF JVCLThemesEnabled}
const
  ArrowDirection: array [TCanvasOrientation] of TScrollDirection = (sdRight, sdLeft);
var
  Details: TThemedElementDetails;
  lCaptionRect: TRect;
  lCellRect: TRect;
  PenRecall: TPenRecall;
{$ENDIF JVCLThemesEnabled}
begin
  {$IFDEF JVCLThemesEnabled}
  if UseXPThemes and ThemeServices.ThemesEnabled then
  begin
    lCellRect := ARect;
    if ThemeServices.ThemesEnabled and (ARow = 0) and (ACol - ColumnOffset >= 0) and (dgTitles in Options) then
    begin
      lCaptionRect := ARect;
      if not FPaintInfo.ColPressed or (FPaintInfo.ColPressedIdx <> ACol) then
      begin
        if (FPaintInfo.MouseInCol = -1) or (FPaintInfo.MouseInCol <> ACol) or (csDesigning in ComponentState) then
          Details := ThemeServices.GetElementDetails(thHeaderItemNormal)
        else
          Details := ThemeServices.GetElementDetails(thHeaderItemHot);
        lCellRect.Right := lCellRect.Right + 1;
        lCellRect.Bottom := lCellRect.Bottom + 1;
      end
      else if AllowTitleClick then
      begin
        Details := ThemeServices.GetElementDetails(thHeaderItemPressed);
        InflateRect(lCaptionRect, -1, 1);
      end
      else
      begin
        if FPaintInfo.MouseInCol = ACol then
          Details := ThemeServices.GetElementDetails(thHeaderItemHot)
        else
          Details := ThemeServices.GetElementDetails(thHeaderItemNormal);
      end;
      ThemeServices.DrawElement(Canvas.Handle, Details, lCellRect);
    end
    else if (ACol = 0) and (dgIndicator in Options) and ThemeServices.ThemesEnabled then
    begin
      // indicator column
      if ARow < TitleOffset then
        Details := ThemeServices.GetElementDetails(thHeaderItemNormal)
      else
        Details := ThemeServices.GetElementDetails(thHeaderRoot);
      lCellRect.Right := lCellRect.Right + 1;
      lCellRect.Bottom := lCellRect.Bottom + 1;
      ThemeServices.DrawElement(Canvas.Handle, Details, lCellRect);
      // draw the indicator
      if (Datalink.Active) and (ARow - TitleOffset = Datalink.ActiveRecord) then
      begin
        PenRecall := TPenRecall.Create(Canvas.Pen);
        try
          Canvas.Pen.Color := clWhite;
          DrawArrow(Canvas, ArrowDirection[Canvas.CanvasOrientation], Point(lCellRect.Left + 4, lCellRect.Top + 3), 5);
          Canvas.Pen.Color := clBlack;
          DrawArrow(Canvas, ArrowDirection[Canvas.CanvasOrientation], Point(lCellRect.Left + 3, lCellRect.Top + 3), 5);
        finally
          PenRecall.Free;
        end;
      end;
    end
    else
      CallDrawCellEvent(ACol, ARow, ARect, AState);
  end
  else
  {$ENDIF JVCLThemesEnabled}
    CallDrawCellEvent(ACol, ARow, ARect, AState);
end;

procedure TJvDBGrid.DrawCell(ACol, ARow: Longint; ARect: TRect; AState: TGridDrawState);
const
  EdgeFlag: array [Boolean] of UINT = (BDR_RAISEDINNER, BDR_SUNKENINNER);
  MinOffs = 1;
var
  FrameOffs: Byte;
  BackColor: TColor;
  ASortMarker: TSortMarker;
  Indicator, ALeft: Integer;
  Down: Boolean;
  Bmp: TJvDBGridBitmap;
  SavePen: TColor;
  OldActive: Longint;
  MultiSelected: Boolean;
  FixRect: TRect;
  TitleRect, TextRect: TRect;
  AField: TField;
  MasterCol: TColumn;
  InBiDiMode: Boolean;
  DrawColumn: TColumn;
  DefaultDrawText, DefaultDrawSortMarker: Boolean;

  function CalcTitleRect(Col: TColumn; ARow: Integer; var MasterCol: TColumn): TRect;
    { copied from Inprise's DbGrids.pas }
  var
    I, J: Integer;
    InBiDiMode: Boolean;
    DrawInfo: TGridDrawInfo;
  begin
    MasterCol := ColumnAtDepth(Col, ARow);
    if MasterCol = nil then
      Exit;
    I := DataToRawColumn(MasterCol.Index);
    if I >= LeftCol then
      J := MasterCol.Depth
    else
    begin
      if (FixedCols > 0) and (MasterCol.Index < FixedCols) then
      begin
        J := MasterCol.Depth;
      end
      else
      begin
        I := LeftCol;
        if Col.Depth > ARow then
          J := ARow
        else
          J := Col.Depth;
      end;
    end;
    Result := CellRect(I, J);
    InBiDiMode := UseRightToLeftAlignment and (Canvas.CanvasOrientation = coLeftToRight);
    for I := Col.Index to Columns.Count - 1 do
    begin
      if ColumnAtDepth(Columns[I], ARow) <> MasterCol then
        Break;
      if not InBiDiMode then
      begin
        J := CellRect(DataToRawColumn(I), ARow).Right;
        if J = 0 then
          Break;
        Result.Right := Max(Result.Right, J);
      end
      else
      begin
        J := CellRect(DataToRawColumn(I), ARow).Left;
        if J >= ClientWidth then
          Break;
        Result.Left := J;
      end;
    end;
    J := Col.Depth;
    if (J <= ARow) and (J < FixedRows - 1) then
    begin
      CalcFixedInfo(DrawInfo);
      Result.Bottom := DrawInfo.Vert.FixedBoundary -
        DrawInfo.Vert.EffectiveLineWidth;
    end;
  end;

  procedure DrawExpandBtn(var TitleRect, TextRect: TRect; InBiDiMode: Boolean;
    Expanded: Boolean); { copied from Inprise's DbGrids.pas }
  const
    ScrollArrows: array [Boolean, Boolean] of Integer =
      ((DFCS_SCROLLRIGHT, DFCS_SCROLLLEFT), (DFCS_SCROLLLEFT, DFCS_SCROLLRIGHT));
  var
    ButtonRect: TRect;
    I: Integer;
  begin
    I := GetSystemMetrics(SM_CXHSCROLL);
    if (TextRect.Right - TextRect.Left) > I then
    begin
      Dec(TextRect.Right, I);
      ButtonRect := TitleRect;
      ButtonRect.Left := TextRect.Right;
      I := SaveDC(Canvas.Handle);
      try
        Canvas.FillRect(ButtonRect);
        InflateRect(ButtonRect, -1, -1);
        with ButtonRect do
          IntersectClipRect(Canvas.Handle, Left, Top, Right, Bottom);
        InflateRect(ButtonRect, 1, 1);
        { DrawFrameControl doesn't draw properly when orientation has changed.
          It draws as ExtTextOut does. }
        if InBiDiMode then { stretch the arrows box }
          Inc(ButtonRect.Right, GetSystemMetrics(SM_CXHSCROLL) + 4);
        DrawFrameControl(Canvas.Handle, ButtonRect, DFC_SCROLL,
          ScrollArrows[InBiDiMode, Expanded] or DFCS_FLAT);
      finally
        RestoreDC(Canvas.Handle, I);
      end;
      TitleRect.Right := ButtonRect.Left;
    end;
  end;

  procedure DrawTitleCaption;
  var
    CalcRect: TRect;
    TitleSpace,
    TitleOptions: Integer;
  begin
    with DrawColumn.Title do
    begin
      TitleOptions := DT_END_ELLIPSIS;
      if WordWrap then
      begin
        CalcRect := TextRect;
        Dec(CalcRect.Right, MinOffs + 1);
        {$IFDEF CLR}
        Windows.DrawText(Canvas.Handle, Caption, -1, CalcRect,
          DT_CALCRECT or DT_LEFT or DT_EXPANDTABS or DT_NOPREFIX or DT_WORDBREAK);
        {$ELSE}
        Windows.DrawText(Canvas.Handle, PChar(Caption), -1, CalcRect,
          DT_CALCRECT or DT_LEFT or DT_EXPANDTABS or DT_NOPREFIX or DT_WORDBREAK);
        {$ENDIF CLR}
        if CalcRect.Bottom > TextRect.Bottom then
        begin
          TitleOptions := DT_END_ELLIPSIS or DT_SINGLELINE;
          TitleSpace := TextRect.Bottom - TextRect.Top - Canvas.TextHeight('^g');
        end
        else
        begin
          if (CalcRect.Bottom - CalcRect.Top) > Canvas.TextHeight('^g') then
            TitleOptions := 0;
          TitleSpace := TextRect.Bottom - CalcRect.Bottom;
        end;
      end
      else
        TitleSpace := TextRect.Bottom - TextRect.Top - Canvas.TextHeight('^g');
      WriteCellText(TextRect, MinOffs, Max(MinOffs, TitleSpace div 2), Caption, Alignment,
        IsRightToLeft, True, TitleOptions);
    end;
  end;

begin
  FCurrentDrawRow := ARow;
  Canvas.Font := Self.Font;
  if (DataLink <> nil) and DataLink.Active and (ACol >= 0) and
    (ACol < Columns.Count) then
  begin
    DrawColumn := Columns[ACol];
    if DrawColumn <> nil then
      Canvas.Font := DrawColumn.Font;
  end;

  DoDrawCell(ACol, ARow, ARect, AState);
  with ARect do
    if FTitleArrow and (ARow = 0) and (ACol = 0) and
      (dgIndicator in Options) and (dgTitles in Options) then
    begin
      Bmp := GetGridBitmap(gpPopup);
      DrawBitmapTransparent(Canvas, (ARect.Left + ARect.Right - Bmp.Width) div 2,
        (ARect.Top + ARect.Bottom - Bmp.Height) div 2, Bmp, clWhite);
    end;

  InBiDiMode := Canvas.CanvasOrientation = coRightToLeft;
  if (dgIndicator in Options) and (ACol = 0) and (ARow - TitleOffset >= 0) and
    MultiSelect and (DataLink <> nil) and DataLink.Active and
    (DataLink.DataSet.State = dsBrowse) then
  begin { draw multiselect indicators if needed }
    FixRect := ARect;
    if [dgRowLines, dgColLines] * Options = [dgRowLines, dgColLines] then
    begin
      InflateRect(FixRect, -1, -1);
      FrameOffs := 1;
    end
    else
      FrameOffs := 2;
    OldActive := DataLink.ActiveRecord;
    try
      DataLink.ActiveRecord := ARow - TitleOffset;
      MultiSelected := ActiveRowSelected;
    finally
      DataLink.ActiveRecord := OldActive;
    end;
    if MultiSelected then
    begin
      if ARow - TitleOffset <> DataLink.ActiveRecord then
        Indicator := 0
      else
        Indicator := 1; { multiselected and current row }
      FMsIndicators.BkColor := FixedColor;
      ALeft := FixRect.Right - FMsIndicators.Width - FrameOffs;
      if InBiDiMode then
        Inc(ALeft);
      FMsIndicators.Draw(Self.Canvas, ALeft, (FixRect.Top +
        FixRect.Bottom - FMsIndicators.Height) shr 1, Indicator);
    end;
  end
  else
  if not (csLoading in ComponentState) and
    (gdFixed in AState) and (dgTitles in Options) and (ARow < TitleOffset) then
  begin
    SavePen := Canvas.Pen.Color;
    try
      Canvas.Pen.Color := clWindowFrame;
      if dgIndicator in Options then
        Dec(ACol, IndicatorOffset);
      AField := nil;
      ASortMarker := smNone;
      if (DataLink <> nil) and DataLink.Active and (ACol >= 0) and
        (ACol < Columns.Count) then
      begin
        DrawColumn := Columns[ACol];
        AField := DrawColumn.Field;
      end
      else
        DrawColumn := nil;
      if Assigned(DrawColumn) and not DrawColumn.Showing then
        Exit;
      TitleRect := CalcTitleRect(DrawColumn, ARow, MasterCol);
      if TitleRect.Right < ARect.Right then
        TitleRect.Right := ARect.Right;
      if MasterCol = nil then
        Exit
      else
      if MasterCol <> DrawColumn then
        AField := MasterCol.Field;
      DrawColumn := MasterCol;
      if ((dgColLines in Options) or FTitleButtons) and (ACol = FixedCols - 1) then
      begin
        if (ACol < Columns.Count - 1) and not (Columns[ACol + 1].Showing) then
        begin
          Canvas.MoveTo(TitleRect.Right, TitleRect.Top);
          Canvas.LineTo(TitleRect.Right, TitleRect.Bottom);
        end;
      end;
      if ((dgRowLines in Options) or FTitleButtons) and not MasterCol.Showing then
      begin
        Canvas.MoveTo(TitleRect.Left, TitleRect.Bottom);
        Canvas.LineTo(TitleRect.Right, TitleRect.Bottom);
      end;
      Down := FPressed and FTitleButtons and (FPressedCol = DrawColumn);
      if FTitleButtons or ([dgRowLines, dgColLines] * Options = [dgRowLines, dgColLines]) then
      begin
        {$IFDEF JVCLThemesEnabled}
        if not (UseXPThemes and ThemeServices.ThemesEnabled) then
        {$ENDIF JVCLThemesEnabled}
        begin
          DrawEdge(Canvas.Handle, TitleRect, EdgeFlag[Down], BF_BOTTOMRIGHT);
          DrawEdge(Canvas.Handle, TitleRect, EdgeFlag[Down], BF_TOPLEFT);
          InflateRect(TitleRect, -1, -1);
        end;
      end;
      Canvas.Font := TitleFont;
      Canvas.Brush.Color := FixedColor;
      if DrawColumn <> nil then
      begin
        Canvas.Font := DrawColumn.Title.Font;
        Canvas.Brush.Color := DrawColumn.Title.Color;
      end;
      if FTitleButtons and (AField <> nil) then
      begin
        BackColor := Canvas.Brush.Color;
        //-----------------------------------------
        // FBC -fix SortMarker
        // Not so elegant, but it works.
        //-----------------------------------------
        if SortMarkerAssigned(AField.FieldName) then
        begin
          ASortMarker := Self.SortMarker;
          DoGetBtnParams(AField, Canvas.Font, BackColor, ASortMarker, Down);
          Self.SortMarker := ASortMarker;
        end
        else
          DoGetBtnParams(AField, Canvas.Font, BackColor, ASortMarker, Down);
        Canvas.Brush.Color := BackColor;
      end;
      if Down then
        OffsetRect(TitleRect, 1, 1);
      ARect := TitleRect;
      if (DataLink = nil) or not DataLink.Active then
      begin
        {$IFDEF JVCLThemesEnabled}
        if not (UseXPThemes and ThemeServices.ThemesEnabled) then
        {$ENDIF JVCLThemesEnabled}
          Canvas.FillRect(TitleRect);
      end
      else
      if DrawColumn <> nil then
      begin
        case ASortMarker of
          smDown:
            Bmp := GetGridBitmap(gpMarkDown);
          smUp:
            Bmp := GetGridBitmap(gpMarkUp);
        else
          Bmp := nil;
        end;
        if Bmp <> nil then
          Indicator := Bmp.Width + 6
        else
          Indicator := 1;
        DefaultDrawText := True;
        DefaultDrawSortMarker := True;
        DoDrawColumnTitle(Canvas, TitleRect, DrawColumn, Bmp, Down, Indicator,
          DefaultDrawText, DefaultDrawSortMarker);
        TextRect := TitleRect;
        if ASortMarker <> smNone then
          Dec(TextRect.Right, Bmp.Width + 4);
        if DefaultDrawText then
        begin
          if DrawColumn.Expandable then
            DrawExpandBtn(TitleRect, TextRect, InBiDiMode, DrawColumn.Expanded);
          DrawTitleCaption;
        end;
        if DefaultDrawSortMarker then
        begin
          if Bmp <> nil then
          begin
            ALeft := TitleRect.Right - Indicator + 3;
            if IsRightToLeft then
              ALeft := TitleRect.Left + 3;
            Canvas.FillRect(Rect(TextRect.Right, TitleRect.Top, TitleRect.Right, TitleRect.Bottom));
            if (ALeft > TitleRect.Left) and (ALeft + Bmp.Width < TitleRect.Right) then
              DrawBitmapTransparent(Canvas, ALeft, (TitleRect.Bottom +
                TitleRect.Top - Bmp.Height) div 2, Bmp, clFuchsia);
          end;
        end;
      end
      else
        WriteCellText(ARect, MinOffs, MinOffs, '', taLeftJustify, False, IsRightToLeft);
    finally
      Canvas.Pen.Color := SavePen;
    end;
  end
  else
  begin
    Canvas.Font := Self.Font;
    if (DataLink <> nil) and DataLink.Active and (ACol >= 0) and
      (ACol < Columns.Count) then
    begin
      DrawColumn := Columns[ACol];
      if DrawColumn <> nil then
        Canvas.Font := DrawColumn.Font;
    end;
  end;
end;

procedure TJvDBGrid.DrawColumnCell(const Rect: TRect; DataCol: Integer;
  Column: TColumn; State: TGridDrawState);
var
  I: Integer;
  NewBackgrnd: TColor;
  Highlight: Boolean;
  Bmp: TBitmap;
  Field: TField;
  MemoText: string;
begin
  Field := Column.Field;
  if Assigned(DataSource) and Assigned(DataSource.DataSet) and DataSource.DataSet.Active and
    (SelectedRows.IndexOf(DataSource.DataSet.Bookmark) > -1) then
    Include(State, gdSelected);
  NewBackgrnd := Canvas.Brush.Color;
  Highlight := (gdSelected in State) and ((dgAlwaysShowSelection in Options) or Focused);
  GetCellProps(Field, Canvas.Font, NewBackgrnd, Highlight or ActiveRowSelected);
  Canvas.Brush.Color := NewBackgrnd;
  if DefaultDrawing then
  begin
    I := GetImageIndex(Field);
    if I >= 0 then
    begin
      Bmp := GetGridBitmap(TGridPicture(I));
      Canvas.FillRect(Rect);
      DrawBitmapTransparent(Canvas, (Rect.Left + Rect.Right + 1 - Bmp.Width) div 2,
        (Rect.Top + Rect.Bottom + 1 - Bmp.Height) div 2, Bmp, clOlive);
    end
    else
    begin
      if (Field is TStringField) or (FShowMemos and ((Field is TMemoField)
        {$IFDEF COMPILER10_UP} or (Field is TWideMemoField) {$ENDIF})) then
      begin
        if Assigned(Field.OnGetText) then
          MemoText := Field.DisplayText
        else
          MemoText := Field.AsString;
        WriteCellText(Rect, 2, 2, MemoText, Column.Alignment,
          UseRightToLeftAlignmentForField(Field, Column.Alignment), False);
      end
      else
        DefaultDrawColumnCell(Rect, DataCol, Column, State);
    end;
  end;
  if (Columns.State = csDefault) or not DefaultDrawing or (csDesigning in ComponentState) then
    inherited DrawDataCell(Rect, Field, State);
  inherited DrawColumnCell(Rect, DataCol, Column, State);
  if DefaultDrawing and (gdFocused in State) and not (csDesigning in ComponentState) and
    not (dgRowSelect in Options) and
    (ValidParentForm(Self).ActiveControl = Self) then
    Canvas.DrawFocusRect(Rect);
end;

procedure TJvDBGrid.DrawDataCell(const Rect: TRect; Field: TField;
  State: TGridDrawState);
begin
end;

procedure TJvDBGrid.MouseToCell(X, Y: Integer; var ACol, ARow: Longint);
var
  Coord: TGridCoord;
begin
  Coord := MouseCoord(X, Y);
  ACol := Coord.X;
  ARow := Coord.Y;
end;

procedure TJvDBGrid.SaveColumnsLayout(const AppStorage: TJvCustomAppStorage;
  const Section: string);
var
  I: Integer;
  SectionName: string;
begin
  if Section <> '' then
    SectionName := Section
  else
    SectionName := GetDefaultSection(Self);
  if Assigned(AppStorage) then
  begin
    AppStorage.DeleteSubTree(SectionName);
    with Columns do
      for I := 0 to Count - 1 do
        AppStorage.WriteString(AppStorage.ConcatPaths([SectionName, Format('%s.%s', [Name, Items[I].FieldName])]),
          Format('%d,%d', [Items[I].Index, Items[I].Width]));
  end;
end;

procedure TJvDBGrid.RestoreColumnsLayout(const AppStorage: TJvCustomAppStorage;
  const Section: string);
const
  Delims = [' ', ','];
type
  TColumnInfo = record
    Column: TColumn;
    EndIndex: Integer;
  end;
  TColumnArray = array of TColumnInfo;
var
  I, J: Integer;
  SectionName, S: string;
  ColumnArray: TColumnArray;
begin
  if Section <> '' then
    SectionName := Section
  else
    SectionName := GetDefaultSection(Self);
  if Assigned(AppStorage) then
    with Columns do
    begin
      SetLength(ColumnArray, Count);
      for I := 0 to Count - 1 do
      begin
        S := AppStorage.ReadString(AppStorage.ConcatPaths([SectionName,
          Format('%s.%s', [Name, Items[I].FieldName])]));
        ColumnArray[I].Column := Items[I];
        ColumnArray[I].EndIndex := Items[I].Index;
        if S <> '' then
        begin
          ColumnArray[I].EndIndex := StrToIntDef(ExtractWord(1, S, Delims), ColumnArray[I].EndIndex);
          S := ExtractWord(2, S, Delims);
          Items[I].Width := StrToIntDef(S, Items[I].Width);
          Items[I].Visible := (S <> '-1');
        end;
      end;
      for I := 0 to Count - 1 do
        for J := 0 to Count - 1 do
          if ColumnArray[J].EndIndex = I then
          begin
            ColumnArray[J].Column.Index := ColumnArray[J].EndIndex;
            Break;
          end;
    end;
end;

procedure TJvDBGrid.LoadFromAppStore(const AppStorage: TJvCustomAppStorage; const Path: string);
begin
  if (DataSource <> nil) and (DataSource.DataSet <> nil) then
  begin
    HandleNeeded;
    BeginLayout;
    try
      if StoreColumns then
        RestoreColumnsLayout(AppStorage, Path)
      else
        InternalRestoreFields(DataSource.DataSet, AppStorage, Path, False);
    finally
      EndLayout;
    end;
  end;
end;

procedure TJvDBGrid.SaveToAppStore(const AppStorage: TJvCustomAppStorage; const Path: string);
begin
  if (DataSource <> nil) and (DataSource.DataSet <> nil) then
    if StoreColumns then
      SaveColumnsLayout(AppStorage, Path)
    else
      InternalSaveFields(DataSource.DataSet, AppStorage, Path);
end;

procedure TJvDBGrid.Load;
begin
  IniLoad(nil);
end;

procedure TJvDBGrid.Save;
begin
  IniSave(nil);
end;

procedure TJvDBGrid.IniSave(Sender: TObject);
var
  Section: string;
begin
  if (Name <> '') and Assigned(IniStorage) then
  begin
    if StoreColumns then
      Section := IniStorage.AppStorage.ConcatPaths([IniStorage.AppStoragePath, GetDefaultSection(Self)])
    else
    if (DataSource <> nil) and
      (DataSource.DataSet <> nil) then
      Section := IniStorage.AppStorage.ConcatPaths([IniStorage.AppStoragePath, DataSetSectionName(DataSource.DataSet)])
    else
      Section := '';
    SaveToAppStore(IniStorage.AppStorage, Section);
  end;
end;

procedure TJvDBGrid.IniLoad(Sender: TObject);
var
  Section: string;
begin
  if (Name <> '') and Assigned(IniStorage) then
  begin
    if StoreColumns then
      Section := IniStorage.AppStorage.ConcatPaths([IniStorage.AppStoragePath, GetDefaultSection(Self)])
    else
    if (DataSource <> nil) and
      (DataSource.DataSet <> nil) then
      Section := IniStorage.AppStorage.ConcatPaths([IniStorage.AppStoragePath, DataSetSectionName(DataSource.DataSet)])
    else
      Section := '';
    LoadFromAppStore(IniStorage.AppStorage, Section);
  end;
end;

procedure TJvDBGrid.CalcSizingState(X, Y: Integer; var State: TGridState;
  var Index: Longint; var SizingPos, SizingOfs: Integer;
  var FixedInfo: TGridDrawInfo);
var
  Coord: TGridCoord;
begin
  inherited CalcSizingState(X, Y, State, Index, SizingPos, SizingOfs, FixedInfo);

  // do nothing if not authorized to size columns
  if not (dgColumnResize in Options) and not (csDesigning in ComponentState) then
    Exit;

  if (State = gsNormal) and (Y <= RowHeights[0]) then
  begin
    Coord := MouseCoord(X, Y);
    CalcDrawInfo(FixedInfo);
    if CellRect(Coord.X, 0).Right - 5 < X then
    begin
      State := gsColSizing;
      Index := Coord.X;
      SizingPos := X;
      SizingOfs := X - CellRect(Coord.X, 0).Right;
    end;
    if CellRect(Coord.X, 0).Left + 5 > X then
    begin
      State := gsColSizing;
      Index := Coord.X - 1;
      SizingPos := X;
      SizingOfs := X - CellRect(Coord.X, 0).Left;
    end;
    if Index <= Byte(dgIndicator in Options) - 1 then
      State := gsNormal;
  end;
  FSizingIndex := Index;
  FSizingOfs := SizingOfs;
end;

procedure TJvDBGrid.DoDrawColumnTitle(ACanvas: TCanvas; ARect: TRect;
  AColumn: TColumn; var ASortMarker: TJvDBGridBitmap; IsDown: Boolean; var Offset: Integer;
  var DefaultDrawText, DefaultDrawSortMarker: Boolean);
begin
  if Assigned(FOnDrawColumnTitle) then
  begin
    FOnDrawColumnTitle(Self, ACanvas, ARect, AColumn, ASortMarker, IsDown, Offset,
      DefaultDrawText, DefaultDrawSortMarker);
  end;
end;

{$IFDEF COMPILER5}
procedure TJvDBGrid.FocusCell(ACol, ARow: Longint; MoveAnchor: Boolean);
begin
  MoveColRow(ACol, ARow, MoveAnchor, True);
  InvalidateEditor;
  Click;
end;
{$ENDIF COMPILER5}

procedure TJvDBGrid.ChangeBoolean(const FieldValueChange: Shortint);
// FieldValueChange = 9 -> invert, 0 -> check (true), -1 -> uncheck (false)
begin
  if Assigned(FBooleanFieldToEdit) and BooleanEditor then
  begin
    DataLink.Edit;
    if DataLink.Editing then
    begin
      if FBooleanFieldToEdit.IsNull or (FieldValueChange <> JvGridBool_INVERT) then
      begin
        case FBooleanFieldToEdit.DataType of
          ftBoolean:
            FBooleanFieldToEdit.Value := (FieldValueChange = JvGridBool_CHECK);
          ftString, ftWideString:
            begin
              if FieldValueChange = JvGridBool_CHECK then
                FBooleanFieldToEdit.Value := FStringForTrue
              else
                FBooleanFieldToEdit.Value := FStringForFalse;
            end;
        else
          FBooleanFieldToEdit.Value := FieldValueChange + 1;
        end;
      end
      else
        case FBooleanFieldToEdit.DataType of
          ftBoolean:
            FBooleanFieldToEdit.Value := not FBooleanFieldToEdit.AsBoolean;
          ftString, ftWideString:
            begin
              if AnsiSameText(FBooleanFieldToEdit.AsString, FStringForTrue) then
                FBooleanFieldToEdit.Value := FStringForFalse
              else
                FBooleanFieldToEdit.Value := FStringForTrue;
            end;
        else
          FBooleanFieldToEdit.Value := 1 - Abs(FBooleanFieldToEdit.AsInteger);
        end;
      InvalidateCell(Col, Row);
    end;
  end;
  FBooleanFieldToEdit := nil;
end;

procedure TJvDBGrid.CellClick(Column: TColumn);
begin
  FTitleColumn := nil;
  inherited CellClick(Column);

  if Assigned(Column.Field) and (FBooleanFieldToEdit = Column.Field) then
    ChangeBoolean(JvGridBool_INVERT); // Invert the field value
end;

procedure TJvDBGrid.EditButtonClick;
begin
  // Just to have it here for the call in TJvDBInplaceEdit
  inherited EditButtonClick;
end;

procedure TJvDBGrid.MouseLeave(Control: TControl);
begin
  if csDesigning in ComponentState then
    Exit;
  inherited MouseLeave(Control);
end;

procedure TJvDBGrid.DoGetBtnParams(Field: TField;
  AFont: TFont; var Background: TColor; var ASortMarker: TSortMarker;
  IsDown: Boolean);
begin
  if Assigned(FOnGetBtnParams) then
    FOnGetBtnParams(Self, Field, AFont, Background, ASortMarker, IsDown);
end;

procedure TJvDBGrid.ColEnter;
begin
  FWord := '';
  inherited ColEnter;
  if FAlwaysShowEditor and not EditorMode then
    ShowEditor;
end;

function TJvDBGrid.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer;
  MousePos: TPoint): Boolean;
begin
  // Do not validate a record by error
  if DataLink.Active and (DataLink.DataSet.State <> dsBrowse) then
    DataLink.DataSet.Cancel;
  Result := inherited DoMouseWheel(Shift, WheelDelta, MousePos);
end;

procedure TJvDBGrid.UpdateTabStops(ALimit: Integer = -1);
var
  I: Integer;
begin
  for I := 0 to Columns.Count - 1 do
    with Columns[I] do
      if ALimit = -1 then
        TabStops[I + IndicatorOffset] := True
      else
        TabStops[I + IndicatorOffset] := (I < ALimit);
end;

procedure TJvDBGrid.SetTitleArrow(const Value: Boolean);
begin
  if FTitleArrow <> Value then
  begin
    FTitleArrow := Value;
    Invalidate;
  end;
end;

procedure TJvDBGrid.DefineProperties(Filer: TFiler);
begin
  inherited DefineProperties(Filer);
  Filer.DefineProperty('AlternRowColor', ReadAlternateRowColor, nil, False);
  Filer.DefineProperty('AlternRowFontColor', ReadAlternateRowFontColor, nil, False);
  Filer.DefineProperty('PostOnEnter', ReadPostOnEnter, nil, False);
end;

procedure TJvDBGrid.ReadPostOnEnter(Reader: TReader);
begin
  PostOnEnterKey := Reader.ReadBoolean;
end;

procedure TJvDBGrid.ReadAlternateRowColor(Reader: TReader);
begin
  if Reader.ReadBoolean then
    AlternateRowColor := JvDefaultAlternateRowColor // this was the previous default row color
  else
    AlternateRowColor := clNone;
end;

procedure TJvDBGrid.SetAlternateRowColor(const Value: TColor);
begin
  if FAlternateRowColor <> Value then
  begin
    FAlternateRowColor := Value;
    Invalidate;
  end;
end;

procedure TJvDBGrid.ReadAlternateRowFontColor(Reader: TReader);
begin
  if Reader.ReadBoolean then
    AlternateRowFontColor := JvDefaultAlternateRowFontColor
  else
    AlternateRowFontColor := clNone;
end;

procedure TJvDBGrid.SetAlternateRowFontColor(const Value: TColor);
begin
  if FAlternateRowFontColor <> Value then
  begin
    FAlternateRowFontColor := Value;
    Invalidate;
  end;
end;

procedure TJvDBGrid.DoAutoSizeColumns;
// This function ignores Min and Max column widths because these values
// bring about two problems:
// - if (min. width * nb. of columns) > total width --> result too large
// - if (max. width * nb. of columns) < total width --> result too small
var
  ColLineWidth, AvailableWidth, TotalColWidth, AWidth: Integer;
  I, ALeftCol, LastColIndex: Integer;
  ScaleFactor: Double;
begin
  if not AutoSizeColumns or FInAutoSize or (Columns.Count = 0) or (FGridState = gsColSizing) then
    Exit;
  FInAutoSize := True;
  ALeftCol := LeftCol;
  try
    // Get useable width
    ColLineWidth := Ord(dgColLines in Options) * GridLineWidth;
    AvailableWidth := ClientWidth;
    if (dgIndicator in Options) then
      Dec(AvailableWidth, IndicatorWidth + ColLineWidth);
    TotalColWidth := 0;
    if FixedCols = 0 then
      BeginLayout;
    try
      // Autosize all columns proportionally
      if AutoSizeColumnIndex = JvGridResizeProportionally then
      begin
        // Get width currently occupied by visible columns
        for I := 0 to Columns.Count - 1 do
          if Columns[I].Visible then
          begin
            Inc(TotalColWidth, Columns[I].Width);
            Dec(AvailableWidth, ColLineWidth);
          end;
        if TotalColWidth = 0 then
          TotalColWidth := 1;
        // Calculate the relationship between what's available and what's in use
        ScaleFactor := AvailableWidth / TotalColWidth;
        if ScaleFactor = 1.0 then
          Exit; // No need to continue - resizing won't change anything
        // Adjust the columns width
        for I := 0 to Columns.Count - 1 do
          if Columns[I].Visible then
          begin
            if I = LastVisibleColumn then
              Columns[I].Width := AvailableWidth
            else
            begin
              AWidth := Round(ScaleFactor * Columns[I].Width);
              if AWidth < 1 then
                AWidth := 1;
              Columns[I].Width := AWidth;
              Dec(AvailableWidth, AWidth);
            end;
          end;
      end
      else
      // Autosize the last visible column
      if AutoSizeColumnIndex = JvGridResizeLastVisibleCol then
      begin
        LastColIndex := LastVisibleColumn;
        if LastColIndex < 0 then
          Exit;
        for I := 0 to Columns.Count - 1 do
          if Columns[I].Visible and (I < LastColIndex) then
            Inc(TotalColWidth, Columns[I].Width + ColLineWidth);
        AWidth := AvailableWidth - TotalColWidth - ColLineWidth;
        if AWidth > 0 then
          Columns[LastColIndex].Width := AWidth;
      end
      else
      // Only autosize one column
      if AutoSizeColumnIndex <= LastVisibleColumn then
      begin
        for I := 0 to Columns.Count - 1 do
          if Columns[I].Visible and (I <> AutoSizeColumnIndex) then
            Inc(TotalColWidth, Columns[I].Width + ColLineWidth);
        AWidth := AvailableWidth - TotalColWidth - ColLineWidth;
        if AWidth > 0 then
          Columns[AutoSizeColumnIndex].Width := AWidth;
      end;
    finally
      if FixedCols = 0 then
        EndLayout;
    end;
  finally
    FInAutoSize := False;
    LeftCol := ALeftCol;
  end;
end;

procedure TJvDBGrid.DoMaxColWidth;
var
  I: Integer;
begin
  if AutoSizeColumns or (MaxColumnWidth <= 0) then
    Exit;
  BeginLayout;
  try
    for I := 0 to Columns.Count - 1 do
      if Columns[I].Visible and (Columns[I].Width > MaxColumnWidth) then
        Columns[I].Width := MaxColumnWidth;
  finally
    EndLayout;
  end;
end;

procedure TJvDBGrid.DoMinColWidth;
var
  I: Integer;
begin
  if AutoSizeColumns or (MinColumnWidth <= 0) then
    Exit;
  BeginLayout;
  try
    for I := 0 to Columns.Count - 1 do
      if Columns[I].Visible and (Columns[I].Width < MinColumnWidth) then
        Columns[I].Width := MinColumnWidth;
  finally
    EndLayout;
  end;
end;

procedure TJvDBGrid.SetAutoSizeColumnIndex(const Value: Integer);
begin
  if FAutoSizeColumnIndex <> Value then
  begin
    FAutoSizeColumnIndex := Value;
    DoAutoSizeColumns;
  end;
end;

procedure TJvDBGrid.SetAutoSizeColumns(const Value: Boolean);
begin
  if FAutoSizeColumns <> Value then
  begin
    FAutoSizeColumns := Value;
    DoAutoSizeColumns;
  end;
end;

procedure TJvDBGrid.SetMaxColumnWidth(const Value: Integer);
begin
  if FMaxColumnWidth <> Value then
  begin
    FMaxColumnWidth := Value;
    DoMaxColWidth;
  end;
end;

procedure TJvDBGrid.SetMinColumnWidth(const Value: Integer);
begin
  if FMinColumnWidth <> Value then
  begin
    FMinColumnWidth := Value;
    DoMinColWidth;
  end;
end;

procedure TJvDBGrid.InitializeColumnsWidth(const MinWidth, MaxWidth: Integer;
  const DisplayWholeTitle: Boolean; const FixedWidths: array of Integer);
var
  SavedValue: Boolean;
  I, J,
  AWidth: Integer;
begin
  // Resize the grid columns with the given widths (0 = default width) and
  // ensure they are wide enough for the title caption (optional).
  // If there are more columns than widths in FixedWidths, the last given width
  // is used for the remaining columns.
  // If Min/MaxWidth < 0, the Min/MaxColumnWidth value is set automatically.
  // If Min/MaxWidth = 0, the Min/MaxColumnWidth value is not modified.
  // If Min/MaxWidth > 0, the Min/MaxColumnWidth value is set to the given value.
  SavedValue := AutoSizeColumns;
  FAutoSizeColumns := False;
  try
    J := Low(FixedWidths);
    if MinWidth > 0 then
      FMinColumnWidth := MinWidth
    else
    if MinWidth < 0 then
      FMinColumnWidth := FixedWidths[J];
    if MaxWidth > 0 then
      FMaxColumnWidth := MaxWidth
    else
    if MaxWidth < 0 then
      FMaxColumnWidth := FixedWidths[J];
    for I := 0 to Columns.Count - 1 do
      if Columns[I].Visible then
      begin
        if FixedWidths[J] < 1 then
          AWidth := Columns[I].DefaultWidth
        else
        begin
          AWidth := FixedWidths[J];
          if (dgTitles in Options) and DisplayWholeTitle then
          begin
            Canvas.Font.Assign(Columns[I].Title.Font);
            if Canvas.TextWidth(Columns[I].Title.Caption) + 4 > AWidth then
              AWidth := Canvas.TextWidth(Columns[I].Title.Caption) + 4;
          end;
        end;
        if AWidth < MinColumnWidth then
        begin
          if MinWidth < 0 then
            FMinColumnWidth := AWidth
          else
          if MinColumnWidth > 0 then
            AWidth := MinColumnWidth;
        end;
        if AWidth > MaxColumnWidth then
        begin
          if MaxWidth < 0 then
            FMaxColumnWidth := AWidth
          else
          if MaxColumnWidth > 0 then
            AWidth := MaxColumnWidth;
        end;
        Columns[I].Width := AWidth;
        if J < High(FixedWidths) then
          J := J + 1;
      end;
  finally
    AutoSizeColumns := SavedValue;
  end;
end;

procedure TJvDBGrid.Resize;
begin
  inherited Resize;
  DoAutoSizeColumns;

  NotifyLayoutChange(lcSizeChanged);
end;

procedure TJvDBGrid.Loaded;
var
  Ctrl_Idx: Integer;
  WinControl: TWinControl;
begin
  inherited Loaded;

  // Edit controls are hidden
  for Ctrl_Idx := 0 to FControls.Count - 1 do
  begin
    WinControl := TWinControl(Owner.FindComponent(FControls.Items[Ctrl_Idx].ControlName));
    if WinControl <> nil then
      WinControl.Visible := False;
  end;

  DoAutoSizeColumns;
end;

function TJvDBGrid.GetMaxColWidth(Default: Integer): Integer;
begin
  if (MaxColumnWidth > 0) and (Default > MaxColumnWidth) then
    Result := MaxColumnWidth
  else
    Result := Default;
end;

function TJvDBGrid.GetMinColWidth(Default: Integer): Integer;
begin
  if (MinColumnWidth > 0) and (Default < MinColumnWidth) then
    Result := MinColumnWidth
  else
    Result := Default;
end;

function TJvDBGrid.FirstVisibleColumn: Integer;
begin
  for Result := 0 to Columns.Count - 1 do
    if Columns[Result].Visible then
      Exit;
  Result := -1;
end;

function TJvDBGrid.LastVisibleColumn: Integer;
begin
  for Result := Columns.Count - 1 downto 0 do
    if Columns[Result].Visible then
      Exit;
  Result := -1;
end;

procedure TJvDBGrid.DblClick;
begin
  if not DoTitleBtnDblClick then
    inherited DblClick;
  FTitleColumn := nil;
end;

function TJvDBGrid.DoTitleBtnDblClick: Boolean;
begin
  Result := Assigned(FOnTitleBtnDblClick) and Assigned(FTitleColumn);
  if Result then
    FOnTitleBtnDblClick(Self, FTitleColumn.Index, FTitleColumn.Field);
end;

procedure TJvDBGrid.TitleClick(Column: TColumn);
begin
  FTitleColumn := Column;
  inherited TitleClick(Column);
  if AllowTitleClick then
  begin
    FPaintInfo.ColPressed := False;
    FPaintInfo.ColPressedIdx := -1;
    {$IFDEF JVCLThemesEnabled}
    if UseXPThemes and ThemeServices.ThemesEnabled then
      if ValidCell(FCell) then
        InvalidateCell(FCell.X, FCell.Y);
    {$ENDIF JVCLThemesEnabled}
  end;
end;

procedure TJvDBGrid.SetSortedField(const Value: string);
begin
  if FSortedField <> Value then
  begin
    FSortedField := Value;
    Invalidate;
  end;
end;

function TJvDBGrid.ChangeSortMarker(const Value: TSortMarker): Boolean;
begin
  Result := (FSortMarker <> Value);
  if Result then
    FSortMarker := Value;
end;

procedure TJvDBGrid.SetSortMarker(const Value: TSortMarker);
begin
  if ChangeSortMarker(Value) then
    Invalidate;
end;

procedure TJvDBGrid.CMHintShow(var Msg: TCMHintShow);
const
  C_TIMEOUT = 250;
var
  ACol, ARow, ATimeOut, SaveRow: Integer;
  AtCursorPosition: Boolean;
  CalcOptions: Integer;
  HintRect: TRect;
  {$IFDEF CLR}
  HintInfo: THintInfo;
  {$ENDIF CLR}
begin
  AtCursorPosition := True;
  {$IFDEF CLR}
  HintInfo := Msg.HintInfo;
  with HintInfo do
  {$ELSE}
  with Msg.HintInfo^ do
  {$ENDIF CLR}
  begin
    HintStr := GetShortHint(Hint);
    ATimeOut := HideTimeOut;
    Self.MouseToCell(CursorPos.X, CursorPos.Y, ACol, ARow);

    //-------------------------------------------------------------------------
    // ARow = -1 if 'outside' a valid cell;
    // Adjust CursorRect
    //-------------------------------------------------------------------------
    if (FShowTitleHint or FShowCellHint) then
    begin
      if (ARow = -1) or ((ARow >= 1) and not FShowCellHint) then
      begin
        if FShowCellHint then
        begin
          CursorRect.Left := CellRect(0, Self.RowCount - 1).Left;
          CursorRect.Top := CellRect(0, Self.RowCount - 1).Bottom;
        end
        else
        begin
          CursorRect.Left := CellRect(0, 0).Left;
          CursorRect.Top := CellRect(0, 0).Bottom;
        end;
      end
      else
        CursorRect := CellRect(ACol, ARow);
    end;

    if dgIndicator in Options then
      Dec(ACol);
    if dgTitles in Options then
      Dec(ARow);

    if FShowTitleHint and (ACol >= 0) and (ARow = -1) then
    begin
      AtCursorPosition := False;
      HintStr := Columns[ACol].FieldName;
      ATimeOut := Max(ATimeOut, Length(HintStr) * C_TIMEOUT);
      if Assigned(FOnShowTitleHint) and DataLink.Active then
        FOnShowTitleHint(Self, Columns[ACol].Field, HintStr, ATimeOut);
      HideTimeOut := ATimeOut;
    end;

    if FShowCellHint and (ACol >= 0) and DataLink.Active and
      ((ARow >= 0) or (not FShowTitleHint)) then
    begin
      AtCursorPosition := False;
      HintStr := Hint;
      SaveRow := DataLink.ActiveRecord;
      try
        CalcOptions := DT_CALCRECT or DT_LEFT or DT_NOPREFIX or DrawTextBiDiModeFlagsReadingOnly;
        if ARow = -1 then
        begin
          Canvas.Font.Assign(Columns[ACol].Title.Font);
          HintStr := Columns[ACol].Title.Caption;
          if WordWrap then
            CalcOptions := CalcOptions or DT_WORDBREAK;
        end
        else
        with Columns[ACol] do
        begin
          Canvas.Font.Assign(Font);
          DataLink.ActiveRecord := ARow;
          if Field <> nil then
          begin
            if Assigned(Field.OnGetText) then
              HintStr := Field.DisplayText
            else
            begin
              if (Field is TStringField) or (Field is TMemoField) then
              begin
                HintStr := Field.AsString;
                if WordWrap then
                  CalcOptions := CalcOptions or DT_WORDBREAK;
              end
              else
              if (Field is TBlobField) or EditWithBoolBox(Field) then
                HintStr := ''
              else
                HintStr := Field.DisplayText;
            end;
          end;
        end;

        if HintStr <> '' then
        begin
          HintRect := Rect(0, 0, Columns[ACol].Width - 4, 0);
          {$IFDEF CLR}
          Windows.DrawText(Canvas.Handle, HintStr, -1, HintRect, CalcOptions);
          {$ELSE}
          Windows.DrawText(Canvas.Handle, PChar(HintStr), -1, HintRect, CalcOptions);
          {$ENDIF CLR}
          if ((HintRect.Bottom - HintRect.Top + 2) < RowHeights[ARow + 1]) and
            ((HintRect.Right - HintRect.Left) < Columns[ACol].Width - 2) then
            HintStr := '';
        end;

        ATimeOut := Max(ATimeOut, Length(HintStr) * C_TIMEOUT);
        if Assigned(FOnShowCellHint) and DataLink.Active then
          FOnShowCellHint(Self, Columns[ACol].Field, HintStr, ATimeOut);
        HideTimeOut := ATimeOut;
      finally
        if DataLink.ActiveRecord <> SaveRow then
          DataLink.ActiveRecord := SaveRow;
      end;
    end;

    if not AtCursorPosition and HintWindowClass.ClassNameIs('THintWindow') then
    begin
      HintPos := ClientToScreen(CursorRect.TopLeft);
    end;
  end;
  {$IFDEF CLR}
  Msg.HintInfo := HintInfo;
  {$ENDIF CLR}
  inherited;
end;

procedure TJvDBGrid.WMVScroll(var Msg: TWMVScroll);
var
  ALeftCol: Integer;
begin
  if (dgRowSelect in Options) then
  begin
    ALeftCol := LeftCol;
    inherited;
    LeftCol := ALeftCol;
  end
  else
    inherited;
end;

procedure TJvDBGrid.SetWordWrap(Value: Boolean);
begin
  if FWordWrap <> Value then
  begin
    FWordWrap := Value;
    Invalidate;
  end;
end;

procedure TJvDBGrid.PlaceControl(Control: TWinControl; ACol, ARow: Integer);
var
  R: TRect;
  GridControl: TJvDBGridControl;
  ClientTopLeft: TPoint;
begin
  // Do not test for Assigned(Control) here or you will end
  // up with an infinite loop of error messages. This check must
  // be done in UseDefaultEditor

  if ReadOnly or not (Control.Enabled and DataLink.DataSet.CanModify) then
  begin
    HideCurrentControl;
    Exit;
  end;

  if Control <> FCurrentControl then
  begin
    HideCurrentControl;
    FCurrentControl := Control;
    FOldControlWndProc := FCurrentControl.WindowProc;
    FCurrentControl.WindowProc := ControlWndProc;
  end;

  if Control.Parent <> Self.Parent then
    Control.Parent := Self.Parent;

  R := CellRect(ACol, ARow);
  if ((R.Right - R.Left) < 1) or ((R.Bottom - R.Top) < 1) then
    // Cell too small to be drawn -> the control is not drawn
    Control.BoundsRect := Rect(0, 0, 0, 0)
  else
  begin
    R.TopLeft := ClientToScreen(R.TopLeft);
    R.TopLeft := TControl(Control.Parent).ScreenToClient(R.TopLeft);
    R.BottomRight := ClientToScreen(R.BottomRight);
    R.BottomRight := TControl(Control.Parent).ScreenToClient(R.BottomRight);

    // Fred: I removed this code because moving a control away from the topleft corner
    // of the cell lets appear the cell and its focus rectangle behind.

    //if Control is TCustomEdit then
    //begin
    //  { The edit control's text is not painted at good position when the control
    //    has no border }
    //  if TOpenCustomEdit(Control).BorderStyle = bsNone then
    //  begin
    //    Inc(R.Left, 2);
    //    Inc(R.Top, 2);
    //  end;
    //end;

    ClientTopLeft := TControl(Control.Parent).ScreenToClient(Self.ClientOrigin);
    GridControl := FControls.ControlByName(Control.Name);
    if GridControl.FitCell in [fcDesignSize, fcBiggest] then
    begin
      if GridControl.FitCell = fcBiggest then
      begin
        // We choose the biggest size between cell size and design size
        if GridControl.FDesignWidth = 0 then
          GridControl.FDesignWidth := Control.Width;
        if (R.Right - R.Left) > GridControl.FDesignWidth then
          Control.Width := R.Right - R.Left
        else
          Control.Width := GridControl.FDesignWidth;
        if GridControl.FDesignHeight = 0 then
          GridControl.FDesignHeight := Control.Height;
        if (R.Bottom - R.Top) > GridControl.FDesignHeight then
          Control.Height := R.Bottom - R.Top
        else
          Control.Height := GridControl.FDesignHeight;
      end;
      // Horizontal alignment of the control
      if (R.Left + Control.Width) > (ClientTopLeft.X + Self.ClientWidth) then
      begin
        Control.Left := (R.Right - Control.Width);  // Right align
        if Control.Left < ClientTopLeft.X then
          Control.Left := ClientTopLeft.X;
      end
      else
        Control.Left := R.Left;                     // Left align
      // Vertical alignment of the control
      if (R.Top + Control.Height) > (ClientTopLeft.Y + Self.ClientHeight) then
      begin
        Control.Top := (R.Bottom - Control.Height); // Bottom align
        if Control.Top < ClientTopLeft.Y then
          Control.Top := ClientTopLeft.Y;
      end
      else
        Control.Top := R.Top;                       // Top align
    end
    else
      // Control drawn at cell size
      Control.BoundsRect := R;
  end;
  Control.BringToFront;
  Control.Show;

  if Self.Visible and Control.Visible and Self.Parent.Visible and GetParentForm(Self).Visible then
  begin
    if dgCancelOnExit in Options then
    begin // Don't cancel the empty record while moving focus
      Options := Options - [dgCancelOnExit];
      Control.SetFocus;
      Options := Options + [dgCancelOnExit];
    end
    else
      Control.SetFocus;
  end;
end;

procedure TJvDBGrid.SetControls(Value: TJvDBGridControls);
begin
  FControls.Assign(Value);
end;

procedure TJvDBGrid.HideCurrentControl;
begin
  if FCurrentControl <> nil then
  begin
    FCurrentControl.WindowProc := FOldControlWndProc;
    if FCurrentControl.HandleAllocated then
    begin
      SendMessage(FCurrentControl.Handle, WM_KILLFOCUS, 0, 0);
      FCurrentControl.Hide;
    end;
    FCurrentControl := nil;
  end;
  FOldControlWndProc := nil;
end;

procedure TJvDBGrid.CloseControl;
begin
  { Do not hide the control if it has the focus because then the WM_KILLFOCUS
    ControlWndProc hook will hide it. }
  if not Visible or (FCurrentControl = nil) or not FCurrentControl.HandleAllocated or
     not FCurrentControl.Focused then
    HideCurrentControl;
  if Visible then
  begin
    SetFocus;
    { If the grid does not have the focus after a SetFocus, one of the executed
      CM_EXIT has failed with an exception or has set the focus to another control.
      In that case the CurrentControl is still active. }
    if (FCurrentControl <> nil) and FCurrentControl.Focused then
      Abort;
  end;
end;

procedure TJvDBGrid.ControlWndProc(var Message: TMessage);
var
  EscapeKey: Boolean;
  CurrentEditor: TJvDBGridControl;
  {$IFDEF CLR}
  MsgKey: TWMKey;
  {$ENDIF CLR}
begin
  if Message.Msg = WM_CHAR then
  begin
    {$IFDEF CLR}
    MsgKey := TWMKey.Create(Message);
    if not DoKeyPress(MsgKey) then
      with MsgKey do
    {$ELSE}
    if not DoKeyPress(TWMChar(Message)) then
      with TWMKey(Message) do
    {$ENDIF CLR}
      begin
        CurrentEditor := FControls.ControlByName(FCurrentControl.Name);
        if (CharCode = VK_RETURN) and (PostOnEnterKey or CurrentEditor.LeaveOnEnterKey) then
        begin
          CloseControl;
          if PostOnEnterKey then
            DataSource.DataSet.CheckBrowseMode;
        end
        else
        if CharCode = VK_TAB then
        begin
          CloseControl;
          PostMessage(Handle, WM_KEYDOWN, VK_TAB, KeyData);
        end
        else
        begin
          EscapeKey := (CharCode = VK_ESCAPE);
          FOldControlWndProc(Message);
          if EscapeKey then
          begin
            CloseControl;
            if Assigned(SelectedField) and (SelectedField.OldValue <> SelectedField.Value) then
              SelectedField.Value := SelectedField.OldValue;
          end;
        end;
      end;
  end
  else
  if Message.Msg = WM_KEYDOWN then
  begin
    with TWMKey(Message) do
    begin
      CurrentEditor := FControls.ControlByName(FCurrentControl.Name);
      if (CurrentEditor <> nil) and CurrentEditor.LeaveOnUpDownKey and
         ((CharCode = VK_UP) or (CharCode = VK_DOWN)) and (KeyDataToShiftState(KeyData) = []) then
      begin
        CloseControl;
        DataSource.DataSet.CheckBrowseMode;
        PostMessage(Handle, WM_KEYDOWN, CharCode, KeyData);
      end
      else
        FOldControlWndProc(Message);
    end;
  end
  else
  begin
    FOldControlWndProc(Message);
    case Message.Msg Of
      WM_GETDLGCODE:
        begin
          CurrentEditor := FControls.ControlByName(FCurrentControl.Name);
          if (CurrentEditor <> nil) and CurrentEditor.LeaveOnUpDownKey then
            Message.Result := Message.Result or DLGC_WANTTAB or DLGC_WANTARROWS;
        end;
      CM_EXIT:
        HideCurrentControl;
    end;
  end;
end;

//=== { TJvSelectDialogColumnStrings } =======================================

constructor TJvSelectDialogColumnStrings.Create;
begin
  inherited Create;
  Caption := RsJvDBGridSelectTitle;
  RealNamesOption := '';//RsJvDBGridSelectOption;
  OK := RsButtonOKCaption;
  NoSelectionWarning := RsJvDBGridSelectWarning;
end;

procedure TJvDBGrid.ShowColumnsDialog;
begin
  ShowSelectColumnClick;
end;

procedure TJvDBGrid.SetSelectColumnsDialogStrings(const Value: TJvSelectDialogColumnStrings);
begin
  // do nothing
end;

procedure TJvDBGrid.ShowSelectColumnClick;
var
  R, WorkArea: TRect;
  Frm: TfrmSelectColumn;
  Pt: TPoint;
begin
  R := CellRect(0, 0);
  Frm := TfrmSelectColumn.Create(Application);
  try
    if not IsRectEmpty(R) then
    begin
      Pt := ClientToScreen(Point(R.Left, R.Bottom + 1));
      {$IFDEF COMPILER5}
      SystemParametersInfo(SPI_GETWORKAREA, 0, @WorkArea, 0);
      {$ELSE}
      WorkArea := Screen.MonitorFromWindow(Handle).WorkareaRect;
      {$ENDIF COMPILER5}
      { force the form the be in the working area }
      if Pt.X + Frm.Width > WorkArea.Right then
        Pt.X := WorkArea.Right - Frm.Width;
      if Pt.Y + Frm.Height > WorkArea.Bottom then
        Pt.Y := WorkArea.Bottom - Frm.Height;
      Frm.SetBounds(Pt.X, Pt.Y, Frm.Width, Frm.Height);
    end;
    Frm.Grid := TJvDBGrid(Self);
    Frm.DataSource := DataLink.DataSource;
    Frm.SelectColumn := FSelectColumn;
    Frm.Caption := SelectColumnsDialogStrings.Caption;
    Frm.cbWithFieldName.Caption := SelectColumnsDialogStrings.RealNamesOption;
    Frm.ButtonOK.Caption := SelectColumnsDialogStrings.OK;
    Frm.NoSelectionWarning := SelectColumnsDialogStrings.NoSelectionWarning;
    Frm.ShowModal;
  finally
    Frm.Free;
  end;
  Invalidate;
end;

procedure TJvDBGrid.SetBooleanEditor(const Value: Boolean);
begin
  if FBooleanEditor <> Value then
  begin
    FBooleanEditor := Value;
    Invalidate;
  end;
end;

procedure TJvDBGrid.SetScrollBars(const Value: TScrollStyle);
var
  Style: Integer;
const
  ScrollStyles: array [TScrollStyle] of Integer = (0, WS_HSCROLL, WS_VSCROLL, WS_HSCROLL or WS_VSCROLL);
begin
  if FScrollBars <> Value then
  begin
    FScrollBars := Value;
    Style := GetWindowLong(Handle, GWL_STYLE);
    SetWindowLong(Handle, GWL_STYLE, Style or ScrollStyles[Value]);
  end;
end;

procedure TJvDBGrid.SetShowMemos(const Value: Boolean);
begin
  if FShowMemos <> Value then
  begin
    FShowMemos := Value;
    Invalidate;
  end;
end;

procedure TJvDBGrid.SetUseXPThemes(Value: Boolean);
begin
  if Value <> FUseXPThemes then
  begin
    FUseXPThemes := Value;
    Invalidate;
  end;
end;

{$IFDEF JVCLThemesEnabled}
function TJvDBGrid.ColumnOffset: Integer;
begin
  if dgIndicator in Options then
    Result := 1
  else
    Result := 0;
end;

function TJvDBGrid.ValidCell(ACell: TGridCoord): Boolean;
begin
  Result := (ACell.X <> -1) and (ACell.Y <> -1);
end;
{$ENDIF JVCLThemesEnabled}

function TJvDBGrid.BeginColumnDrag(var Origin: Integer; var Destination: Integer; const MousePt: TPoint): Boolean;
begin
  Result := inherited BeginColumnDrag(Origin, Destination, MousePt);
  FPaintInfo.ColMoving := Result;
end;

procedure TJvDBGrid.CMMouseEnter(var Message: TMessage);
{$IFDEF JVCLThemesEnabled}
var
  Cell: TGridCoord;
  lPt: TPoint;
{$ENDIF JVCLThemesEnabled}
begin
  {$IFDEF JVCLThemesEnabled}
  lPt := Point(Mouse.CursorPos.X, Mouse.CursorPos.Y);
  Cell := MouseCoord(lPt.X, lPt.Y);
  if UseXPThemes and ThemeServices.ThemesEnabled then
    if (dgTitles in Options) and (Cell.Y = 0) then
      InvalidateCell(Cell.X, Cell.Y);
  {$ENDIF JVCLThemesEnabled}
end;

procedure TJvDBGrid.CMMouseLeave(var Message: TMessage);
begin
  {$IFDEF JVCLThemesEnabled}
  if UseXPThemes and ThemeServices.ThemesEnabled then
    if ValidCell(FCell) then
      InvalidateCell(FCell.X, FCell.Y);
  {$ENDIF JVCLThemesEnabled}
  FCell.X := -1;
  FCell.Y := -1;
  FPaintInfo.MouseInCol := -1;
  FPaintInfo.ColPressedIdx := -1;
end;

procedure TJvDBGrid.ColExit;
begin
  inherited ColExit;
  FPaintInfo.MouseInCol := -1;
  {$IFDEF JVCLThemesEnabled}
  if UseXPThemes and ThemeServices.ThemesEnabled then
    if ValidCell(FCell) then
      InvalidateCell(FCell.X, FCell.Y);
  {$ENDIF JVCLThemesEnabled}
end;

function TJvDBGrid.AllowTitleClick: Boolean;
begin
  Result := Assigned(FOnTitleBtnClick) or AutoSort;
end;

procedure TJvDBGrid.ColumnMoved(FromIndex, ToIndex: Integer);
begin
  inherited ColumnMoved(FromIndex, ToIndex);
  FPaintInfo.ColMoving := False;
  {$IFDEF JVCLThemesEnabled}
  if UseXPThemes and ThemeServices.ThemesEnabled then
    Invalidate;
  {$ENDIF JVCLThemesEnabled}
end;

procedure TJvDBGrid.MouseWheelHandler(var Message: TMessage);
var
  LastRow: Integer;
begin
  { Fix MouseWheel indicator bug }
  LastRow := Row;
  inherited MouseWheelHandler(Message);
  if (Row <> LastRow) and (DataLink <> nil) and DataLink.Active then
  begin
    DataLink.DataSet.MoveBy(Row - LastRow);
    InvalidateCell(IndicatorOffset - 1, LastRow);
  end;
end;


initialization
  {$IFDEF UNITVERSIONING}
  RegisterUnitVersion(HInstance, UnitVersioning);
  {$ENDIF UNITVERSIONING}

finalization
  FinalizeGridBitmaps;
  {$IFDEF UNITVERSIONING}
  UnregisterUnitVersion(HInstance);
  {$ENDIF UNITVERSIONING}

end.
