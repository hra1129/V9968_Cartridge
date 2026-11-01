// -----------------------------------------------------------------------------
//	V9968UPD for Windows
//	Copyright (C)2026 HRA!
//	MIT License
// -----------------------------------------------------------------------------
using System;
using System.Drawing;
using System.IO;
using System.Windows.Forms;

namespace V9968UpdWin
{
	internal sealed class ProgrammerPathForm : Form
	{
		private readonly TextBox _path = new TextBox();

		public string SelectedPath { get; private set; }

		// Returns the selected and saved path, or null when cancelled.
		public static string Ask( IWin32Window owner, string current )
		{
			using( var form = new ProgrammerPathForm( current ) ) {
				if( form.ShowDialog( owner ) != DialogResult.OK ) {
					return null;
				}
				ProgrammerLocator.Save( form.SelectedPath );
				return form.SelectedPath;
			}
		}

		private ProgrammerPathForm( string current )
		{
			Text = UiText.PathFormTitle;
			FormBorderStyle = FormBorderStyle.FixedDialog;
			MaximizeBox = false;
			MinimizeBox = false;
			StartPosition = FormStartPosition.CenterParent;
			AutoScaleMode = AutoScaleMode.Font;
			Font = new Font( UiText.FontName, 9F );
			ClientSize = new Size( 560, 170 );

			var message = new Label {
				Text = UiText.PathFormMessage,
				Location = new Point( 12, 12 ),
				Size = new Size( 536, 60 ),
			};
			_path.Location = new Point( 12, 82 );
			_path.Size = new Size( 446, 23 );
			_path.Text = current ?? "";

			var browse = new Button { Text = UiText.BrowseButton, Location = new Point( 466, 81 ), Size = new Size( 82, 26 ) };
			browse.Click += OnBrowse;

			var ok = new Button { Text = "OK", Location = new Point( 372, 128 ), Size = new Size( 84, 28 ) };
			ok.Click += OnOk;
			var cancel = new Button { Text = UiText.CancelButton, Location = new Point( 464, 128 ), Size = new Size( 84, 28 ), DialogResult = DialogResult.Cancel };

			Controls.AddRange( new Control[] { message, _path, browse, ok, cancel } );
			AcceptButton = ok;
			CancelButton = cancel;
		}

		private void OnBrowse( object sender, EventArgs e )
		{
			using( var dialog = new OpenFileDialog() ) {
				dialog.Title = UiText.SelectCliTitle;
				dialog.Filter = UiText.CliFileFilter;
				if( File.Exists( _path.Text ) ) {
					dialog.InitialDirectory = Path.GetDirectoryName( _path.Text );
				}
				if( dialog.ShowDialog( this ) == DialogResult.OK ) {
					_path.Text = dialog.FileName;
				}
			}
		}

		private void OnOk( object sender, EventArgs e )
		{
			string path = _path.Text.Trim().Trim( '"' );
			if( !ProgrammerLocator.IsValid( path ) ) {
				MessageBox.Show( this, UiText.CliNotFoundAtPath, Text,
					MessageBoxButtons.OK, MessageBoxIcon.Warning );
				return;
			}
			SelectedPath = path;
			DialogResult = DialogResult.OK;
		}
	}
}
