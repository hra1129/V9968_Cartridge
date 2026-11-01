// -----------------------------------------------------------------------------
//	V9968UPD for Windows
//	Copyright (C)2026 HRA!
//	MIT License
// -----------------------------------------------------------------------------
using System;
using System.Drawing;
using System.IO;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace V9968UpdWin
{
	internal sealed class WizardForm : Form
	{
		private const double ConfigStepEnd = 88.0;
		private const double VersionStepEnd = 97.0;
		private const int ReferenceConfigSize = 907418;

		private ProgrammerCli _cli;
		private ConfigImage _image;
		private bool _busy;
		private bool _completed;
		private int _page;
		private string _stepName = "";

		private readonly Panel[] _pages = new Panel[ 3 ];
		private readonly Button _back = new Button();
		private readonly Button _next = new Button();
		private readonly Button _close = new Button();

		private readonly TextBox _filePath = new TextBox();
		private readonly Label _fileInfo = new Label();

		private readonly Label _connectStatus = new Label();
		private readonly Label _cliPathLabel = new Label();

		private readonly Button _start = new Button();
		private readonly ProgressBar _progressBar = new ProgressBar();
		private readonly Label _progressText = new Label();
		private readonly Label _version = new Label();
		private readonly Label _result = new Label();
		private readonly TextBox _log = new TextBox();

		private readonly ProgressModel _progress = new ProgressModel();
		private readonly Timer _timer = new Timer();

		public WizardForm( string cliPath )
		{
			_cli = new ProgrammerCli( cliPath );

			Text = "V9968UPD for Windows";
			FormBorderStyle = FormBorderStyle.FixedDialog;
			MaximizeBox = false;
			StartPosition = FormStartPosition.CenterScreen;
			AutoScaleMode = AutoScaleMode.Font;
			Font = new Font( UiText.FontName, 9F );
			ClientSize = new Size( 600, 420 );
			AllowDrop = true;
			DragEnter += OnDragEnter;
			DragDrop += OnDragDrop;

			_pages[ 0 ] = CreateFilePage();
			_pages[ 1 ] = CreateConnectPage();
			_pages[ 2 ] = CreateWritePage();
			foreach( Panel page in _pages ) {
				page.Location = new Point( 0, 0 );
				page.Size = new Size( 600, 360 );
				Controls.Add( page );
			}

			var separator = new Label { BorderStyle = BorderStyle.Fixed3D, Location = new Point( 0, 362 ), Size = new Size( 600, 2 ) };
			_back.Text = UiText.BackButton;
			_back.SetBounds( 296, 378, 90, 28 );
			_back.Click += OnBack;
			_next.Text = UiText.NextButton;
			_next.SetBounds( 392, 378, 90, 28 );
			_next.Click += OnNext;
			_close.Text = UiText.CancelButton;
			_close.SetBounds( 498, 378, 90, 28 );
			_close.Click += ( s, e ) => Close();
			Controls.AddRange( new Control[] { separator, _back, _next, _close } );

			_timer.Interval = 200;
			_timer.Tick += ( s, e ) => UpdateProgressBar();

			ShowPage( 0 );
		}

		// ---------------------------------------------------------------------
		// Pages
		// ---------------------------------------------------------------------
		private Panel CreateFilePage()
		{
			var page = new Panel();
			page.Controls.Add( Title( UiText.FilePageTitle ) );
			page.Controls.Add( Caption( UiText.FilePageCaption, 20, 56, 560, 44 ) );

			_filePath.SetBounds( 20, 112, 468, 23 );
			_filePath.AllowDrop = true;
			_filePath.DragEnter += OnDragEnter;
			_filePath.DragDrop += OnDragDrop;
			_filePath.TextChanged += ( s, e ) => { _image = null; _fileInfo.Text = ""; };
			page.Controls.Add( _filePath );

			var browse = new Button { Text = UiText.BrowseButton };
			browse.SetBounds( 496, 111, 84, 26 );
			browse.Click += OnBrowse;
			page.Controls.Add( browse );

			_fileInfo.SetBounds( 20, 150, 560, 60 );
			page.Controls.Add( _fileInfo );
			return page;
		}

		private Panel CreateConnectPage()
		{
			var page = new Panel();
			page.Controls.Add( Title( UiText.ConnectPageTitle ) );
			var message = Caption( UiText.ConnectPrompt, 20, 60, 560, 28 );
			message.Font = new Font( Font.FontFamily, 12F, FontStyle.Bold );
			page.Controls.Add( message );
			page.Controls.Add( Caption( UiText.ConnectCaption, 20, 100, 560, 48 ) );

			_connectStatus.SetBounds( 20, 160, 560, 70 );
			_connectStatus.ForeColor = Color.Firebrick;
			page.Controls.Add( _connectStatus );

			_cliPathLabel.SetBounds( 20, 300, 470, 40 );
			_cliPathLabel.ForeColor = SystemColors.GrayText;
			page.Controls.Add( _cliPathLabel );
			var change = new LinkLabel { Text = UiText.ChangeCliLink };
			change.SetBounds( 496, 300, 84, 20 );
			change.LinkClicked += OnChangeCli;
			page.Controls.Add( change );
			return page;
		}

		private Panel CreateWritePage()
		{
			var page = new Panel();
			page.Controls.Add( Title( UiText.WritePageTitle ) );
			page.Controls.Add( Caption( UiText.WritePageCaption, 20, 52, 560, 40 ) );

			_start.Text = UiText.StartWriteButton;
			_start.SetBounds( 20, 100, 120, 30 );
			_start.Click += OnStart;
			page.Controls.Add( _start );

			_progressBar.SetBounds( 20, 142, 560, 24 );
			_progressBar.Maximum = 1000;
			page.Controls.Add( _progressBar );

			_progressText.SetBounds( 20, 170, 560, 20 );
			page.Controls.Add( _progressText );
			_version.SetBounds( 20, 192, 560, 20 );
			page.Controls.Add( _version );
			_result.SetBounds( 20, 216, 560, 20 );
			_result.Font = new Font( Font.FontFamily, 9F, FontStyle.Bold );
			page.Controls.Add( _result );

			_log.SetBounds( 20, 240, 560, 114 );
			_log.Multiline = true;
			_log.ReadOnly = true;
			_log.ScrollBars = ScrollBars.Vertical;
			_log.Font = new Font( FontFamily.GenericMonospace, 8.5F );
			page.Controls.Add( _log );
			return page;
		}

		private Label Title( string text )
		{
			return new Label {
				Text = text,
				Location = new Point( 20, 16 ),
				Size = new Size( 560, 30 ),
				Font = new Font( Font.FontFamily, 13F, FontStyle.Bold ),
			};
		}

		private static Label Caption( string text, int x, int y, int w, int h )
		{
			return new Label { Text = text, Location = new Point( x, y ), Size = new Size( w, h ) };
		}

		private void ShowPage( int page )
		{
			_page = page;
			for( int i = 0; i < _pages.Length; i++ ) {
				_pages[ i ].Visible = ( i == page );
			}
			if( page == 1 ) {
				_cliPathLabel.Text = "GOWIN Programmer CLI: " + _cli.Path;
			}
			if( page == 2 ) {
				ResetWritePage();
			}
			UpdateButtons();
		}

		private void UpdateButtons()
		{
			_back.Enabled = !_busy && !_completed && _page > 0;
			_next.Enabled = !_busy && _page < 2;
			_next.Visible = _page < 2;
			_start.Enabled = !_busy && !_completed;
			_close.Enabled = !_busy;
			_close.Text = _completed ? UiText.DoneButton : UiText.CancelButton;
		}

		// ---------------------------------------------------------------------
		// Page 1: file selection
		// ---------------------------------------------------------------------
		private void OnDragEnter( object sender, DragEventArgs e )
		{
			e.Effect = ( _page == 0 && e.Data.GetDataPresent( DataFormats.FileDrop ) ) ? DragDropEffects.Copy : DragDropEffects.None;
		}

		private void OnDragDrop( object sender, DragEventArgs e )
		{
			var files = e.Data.GetData( DataFormats.FileDrop ) as string[];
			if( _page == 0 && files != null && files.Length > 0 ) {
				_filePath.Text = files[ 0 ];
			}
		}

		private void OnBrowse( object sender, EventArgs e )
		{
			using( var dialog = new OpenFileDialog() ) {
				dialog.Title = UiText.SelectConfigFileTitle;
				dialog.Filter = UiText.ConfigFileFilter;
				string current = _filePath.Text.Trim().Trim( '"' );
				if( File.Exists( current ) ) {
					dialog.InitialDirectory = Path.GetDirectoryName( current );
				}
				if( dialog.ShowDialog( this ) == DialogResult.OK ) {
					_filePath.Text = dialog.FileName;
				}
			}
		}

		private bool ValidateFile()
		{
			string path = _filePath.Text.Trim().Trim( '"' );
			if( path.Length == 0 || !File.Exists( path ) ) {
				ShowError( UiText.FileNotFound, "Cannot open the file." );
				return false;
			}
			string error;
			ConfigImage image = ConfigImage.Load( path, out error );
			if( image == null ) {
				ShowError( UiText.FileNotUsable, error );
				return false;
			}
			_image = image;
			_fileInfo.Text = string.Format( "Version : {0}\r\nData    : {1:N0} bytes", image.VersionText, image.Data.Length );
			return true;
		}

		// ---------------------------------------------------------------------
		// Page 2: connection check
		// ---------------------------------------------------------------------
		private void OnChangeCli( object sender, LinkLabelLinkClickedEventArgs e )
		{
			string path = ProgrammerPathForm.Ask( this, _cli.Path );
			if( path != null ) {
				_cli = new ProgrammerCli( path );
				_cliPathLabel.Text = "GOWIN Programmer CLI: " + path;
			}
		}

		private async Task<bool> CheckConnectionAsync()
		{
			_connectStatus.ForeColor = SystemColors.ControlText;
			_connectStatus.Text = UiText.CheckingConnection;
			SetBusy( true );
			CliResult scan;
			try {
				scan = await _cli.ScanAsync( null );
			}
			finally {
				SetBusy( false );
			}

			string reason;
			if( ProgrammerCli.IsTargetDevice( scan, out reason ) ) {
				_connectStatus.Text = "";
				return true;
			}
			_connectStatus.ForeColor = Color.Firebrick;
			_connectStatus.Text = "V9968 Cartridge is not detected.\r\n" + reason + "\r\n" + scan.Tail( 2 );
			return false;
		}

		// ---------------------------------------------------------------------
		// Page 3: write
		// ---------------------------------------------------------------------
		private void ResetWritePage()
		{
			_progress.Reset();
			_progressBar.Value = 0;
			_progressText.Text = "";
			_result.Text = "";
			_log.Clear();
			_version.Text = UiText.VersionToWrite + _image.VersionText;
		}

		private async void OnStart( object sender, EventArgs e )
		{
			string tempDir = Path.Combine( Path.GetTempPath(), "V9968UpdWin", Guid.NewGuid().ToString( "N" ) );
			string configFile = Path.Combine( tempDir, "config.bin" );
			string versionFile = Path.Combine( tempDir, "version.bin" );

			_progress.Reset();
			_progressBar.Value = 0;
			_result.Text = "";
			_result.ForeColor = SystemColors.ControlText;
			_log.Clear();
			SetBusy( true );
			_timer.Start();
			try {
				Directory.CreateDirectory( tempDir );
				File.WriteAllBytes( configFile, _image.Data );
				File.WriteAllBytes( versionFile, _image.CreateVersionBlock() );

				AppendLog( string.Format( "File    : {0}", _filePath.Text.Trim().Trim( '"' ) ) );
				AppendLog( string.Format( "Version : {0}", _image.VersionText ) );

				// Config data: the version is updated only after this succeeds, as V9968UPD.COM does.
				_stepName = "Config data";
				_progress.BeginStep( 0.0, ConfigStepEnd, (double)_image.Data.Length / ReferenceConfigSize );
				CliResult config = await _cli.WriteBinaryAsync( configFile, 0x000000, OnCliLine );
				if( !config.Succeeded ) {
					Fail( config, true );
					return;
				}
				_progress.Complete( ConfigStepEnd );

				AppendLog( "Version update" );
				_stepName = UiText.StepVersion;
				_progress.BeginStep( ConfigStepEnd, VersionStepEnd - ConfigStepEnd, 0.1 );
				CliResult version = await _cli.WriteBinaryAsync( versionFile, ConfigImage.VersionBlockAddress, OnCliLine );
				if( !version.Succeeded ) {
					Fail( version, false );
					return;
				}
				_progress.Complete( VersionStepEnd );

				// Reload the FPGA from the updated ConfigROM. Failure here does not affect the written data.
				_stepName = UiText.StepReprogram;
				_progress.BeginStep( VersionStepEnd, 100.0 - VersionStepEnd, 0.1 );
				CliResult reprogram = await _cli.ReprogramAsync( OnCliLine );
				_progress.Complete( 100.0 );
				UpdateProgressBar();

				_completed = true;
				_version.Text = UiText.WrittenVersion + _image.VersionText;
				_progressText.Text = "Config data has been updated.";
				_result.ForeColor = Color.DarkGreen;
				_result.Text = UiText.WriteCompleted;
				if( !reprogram.Succeeded ) {
					AppendLog( "Reprogram failed: " + reprogram.Tail( 1 ) );
					MessageBox.Show( this, UiText.ReprogramFailedMessage,
						Text, MessageBoxButtons.OK, MessageBoxIcon.Information );
				}
			}
			catch( Exception ex ) {
				_result.ForeColor = Color.Firebrick;
				_result.Text = "File read error.";
				AppendLog( ex.Message );
				ShowError( UiText.TempFileFailed, "File read error.\r\n" + ex.Message );
			}
			finally {
				_timer.Stop();
				SetBusy( false );
				try {
					Directory.Delete( tempDir, true );
				}
				catch( Exception ) {
					// Temporary files are best-effort cleanup.
				}
			}
		}

		private void Fail( CliResult result, bool configStep )
		{
			string english;
			if( result.Output != null && result.Output.IndexOf( "No Gowin devices found", StringComparison.OrdinalIgnoreCase ) >= 0 ) {
				english = "V9968 Cartridge is not detected.";
			}
			else {
				switch( _progress.Phase ) {
				case CliPhase.Erasing:		english = "Erase error.";	break;
				case CliPhase.Verifying:	english = "Verify error.";	break;
				default:					english = "Write error.";	break;
				}
			}
			_result.ForeColor = Color.Firebrick;
			_result.Text = english;
			_progressText.Text = configStep ? UiText.ConfigWriteFailed
											: UiText.VersionWriteFailed;
			AppendLog( english );
			AppendLog( "exit code = " + result.ExitCode );
			AppendLog( "command   = " + result.CommandLine );

			ShowError( UiText.WriteFailedMessage,
				english + "\r\n\r\n" + result.Tail( 6 ) );
		}

		private void OnCliLine( string line )
		{
			_progress.OnLine( line );
			AppendLog( line );
		}

		private void AppendLog( string line )
		{
			if( InvokeRequired ) {
				BeginInvoke( new Action<string>( AppendLog ), line );
				return;
			}
			_log.AppendText( line + Environment.NewLine );
		}

		private void UpdateProgressBar()
		{
			double value = _progress.Current;
			_progressBar.Value = Math.Max( _progressBar.Value, Math.Min( 1000, (int)( value * 10.0 ) ) );
			if( !_busy ) {
				return;
			}
			string phase;
			switch( _progress.Phase ) {
			case CliPhase.Erasing:		phase = UiText.PhaseErasing;		break;
			case CliPhase.Programming:	phase = UiText.PhaseWriting;		break;
			case CliPhase.Verifying:	phase = UiText.PhaseVerifying;	break;
			default:					phase = UiText.PhasePreparing;		break;
			}
			_progressText.Text = string.Format( "{0:0}%  {1} {2}...", value, _stepName, phase );
		}

		// ---------------------------------------------------------------------
		// Navigation
		// ---------------------------------------------------------------------
		private void OnBack( object sender, EventArgs e )
		{
			if( _page > 0 ) {
				ShowPage( _page - 1 );
			}
		}

		private async void OnNext( object sender, EventArgs e )
		{
			if( _page == 0 ) {
				if( ValidateFile() ) {
					_connectStatus.Text = "";
					ShowPage( 1 );
				}
			}
			else if( _page == 1 ) {
				if( await CheckConnectionAsync() ) {
					ShowPage( 2 );
				}
			}
		}

		private void SetBusy( bool busy )
		{
			_busy = busy;
			UseWaitCursor = busy && _page == 1;
			UpdateButtons();
		}

		private void ShowError( string message, string detail )
		{
			MessageBox.Show( this, UiText.FormatError( message, detail ), Text, MessageBoxButtons.OK, MessageBoxIcon.Error );
		}

		protected override void OnFormClosing( FormClosingEventArgs e )
		{
			if( _busy ) {
				e.Cancel = true;
				return;
			}
			base.OnFormClosing( e );
		}
	}
}
