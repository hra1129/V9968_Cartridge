// -----------------------------------------------------------------------------
//	V9968UPD for Windows
//	Copyright (C)2026 HRA!
//	MIT License
// -----------------------------------------------------------------------------
//
//	UI text table, Japanese build. UiText.En.cs declares exactly the same
//	members in English; the project compiles only one of the two files,
//	selected by the UiLanguage MSBuild property (default: Ja).
//

namespace V9968UpdWin
{
	internal static class UiText
	{
		// Font for the forms. The English build uses a font that ships with
		// English Windows installations.
		public const string FontName = "Yu Gothic UI";

		// Wizard navigation buttons.
		public const string BackButton = "< 戻る";
		public const string NextButton = "次へ >";
		public const string CancelButton = "キャンセル";
		public const string DoneButton = "完了";

		// Page 1: file selection.
		public const string FilePageTitle = "1. 更新ファイルの選択";
		public const string FilePageCaption = "リリースされている V9968 のデザインの V9968CFG.BIN を選択してください。\r\nパスを直接入力するか、ファイルをこのウィンドウへドロップするか、[参照...] で選択してください。";
		public const string BrowseButton = "参照...";
		public const string SelectConfigFileTitle = "V9968CFG.BIN を選択";
		public const string ConfigFileFilter = "V9968 Config image (*.bin)|*.bin|すべてのファイル (*.*)|*.*";
		public const string FileNotFound = "ファイルが見つかりません。";
		public const string FileNotUsable = "選択されたファイルは V9968CFG.BIN として使用できません。";

		// Page 2: connection.
		public const string ConnectPageTitle = "2. V9968 Cartridge の接続";
		public const string ConnectPrompt = "V9968 Cartridge を接続してください。";
		public const string ConnectCaption = "Tang Nano 20K の USB コネクタと PC を USB ケーブルで接続してから [次へ] をクリックしてください。\r\nGOWIN Programmer (GUI) を起動している場合は、終了してから実行してください。";
		public const string ChangeCliLink = "CLI の変更...";
		public const string CheckingConnection = "接続を確認しています...";

		// Page 3: write.
		public const string WritePageTitle = "3. 書込み";
		public const string WritePageCaption = "[書込み開始] をクリックすると、ConfigROM の消去・書込み・ベリファイを行います。\r\n完了するまで USB ケーブルを抜かないでください。";
		public const string StartWriteButton = "書込み開始";
		public const string VersionToWrite = "書き込むバージョン: ";
		public const string WrittenVersion = "書き込んだバージョン: ";
		public const string StepVersion = "バージョン情報";
		public const string StepReprogram = "FPGA 再起動";
		public const string WriteCompleted = "書き込みが正常に完了しました";
		public const string ReprogramFailedMessage = "書き込みは正常に完了しましたが、FPGA の再起動に失敗しました。\r\nUSB ケーブルを抜き差しして、V9968 Cartridge を再起動してください。";
		public const string TempFileFailed = "一時ファイルの作成に失敗しました。";
		public const string ConfigWriteFailed = "Config data の書き込みに失敗しました。バージョン領域は更新していません。";
		public const string VersionWriteFailed = "バージョン情報の書き込みに失敗しました。";
		public const string WriteFailedMessage = "書き込みに失敗しました。\r\nFlash 内の ConfigROM が未完成の可能性があるため、再度書込みを試行するか、\r\nGOWIN Programmer で書き込んでください。";
		public const string PhaseErasing = "消去中";
		public const string PhaseWriting = "書込み中";
		public const string PhaseVerifying = "ベリファイ中";
		public const string PhasePreparing = "準備中";

		// ProgrammerPathForm (programmer_cli.exe path dialog).
		public const string PathFormTitle = "GOWIN Programmer CLI の指定";
		public const string PathFormMessage = "GOWIN Programmer CLI (programmer_cli.exe) が見つかりませんでした。\r\nGOWIN Programmer のインストール先にある programmer_cli.exe を指定してください。\r\n例: C:\\Gowin\\Gowin_V1.9.12.03_x64\\Programmer\\bin\\programmer_cli.exe";
		public const string SelectCliTitle = "programmer_cli.exe を選択";
		public const string CliFileFilter = "programmer_cli.exe|programmer_cli.exe|実行ファイル (*.exe)|*.exe";
		public const string CliNotFoundAtPath = "指定されたパスに programmer_cli.exe がありません。";

		// ProgrammerCli device check results and log lines.
		public const string DeviceNotFound = "V9968 Cartridge (Tang Nano 20K) が見つかりません。";
		public const string WrongDeviceFormat = "接続されている FPGA が Tang Nano 20K (GW2AR-18C) ではありません。\r\n検出: {0}";
		public const string CliStartFailedPrefix = "Error: programmer_cli を起動できません: ";

		// Combines the two parts of an error dialog. The Japanese build shows
		// the Japanese message followed by the English detail, as before.
		public static string FormatError( string message, string detail )
		{
			return message + "\r\n\r\n" + detail;
		}
	}
}
