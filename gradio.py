import gradio as gr
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from cryptography.fernet import Fernet

# Function to generate plots based on user input
def generate_plot(num_points, plot_type):
    """
    Generates a matplotlib figure based on the selected function type and number of points.
    """
    # Create x values
    x = np.linspace(0, 4 * np.pi, int(num_points))
    # Select function type
    if plot_type == "Sine":
        y = np.sin(x)
    elif plot_type == "Cosine":
        y = np.cos(x)
    elif plot_type == "Linear":
        y = x
    elif plot_type == "Quadratic":
        y = x**2
    elif plot_type == "Random":
        y = np.random.randn(len(x))
    else:
        # Default to sine if unknown
        y = np.sin(x)
    # Create the plot
    fig, ax = plt.subplots()
    ax.plot(x, y, marker='o' if plot_type == "Random" else '')
    ax.set_title(f"{plot_type} Plot")
    ax.set_xlabel("x")
    ax.set_ylabel("y")
    plt.tight_layout()
    return fig

# Function to encrypt and decrypt text using Fernet symmetric encryption
def encrypt_text(message):
    """
    Encrypts the given message and then decrypts it to demonstrate full round-trip.
    Returns the key, encrypted text, and decrypted text.
    """
    # Generate a key
    key = Fernet.generate_key()
    f = Fernet(key)
    # Ensure message is bytes
    message_bytes = message.encode('utf-8')
    # Encrypt the message
    encrypted = f.encrypt(message_bytes)
    # Decrypt the message
    decrypted = f.decrypt(encrypted)
    # Return key, encrypted text, decrypted text (all decoded to strings)
    return key.decode(), encrypted.decode(), decrypted.decode()

# Function to process an uploaded CSV file
def process_csv(file):
    """
    Reads the uploaded CSV file, returns summary statistics and
    a histogram of the first numeric column if available.
    """
    # Read CSV into DataFrame
    df = pd.read_csv(file.name)
    # Compute summary statistics
    stats_df = df.describe().round(2)
    # Create a histogram plot of the first numeric column
    numeric_cols = df.select_dtypes(include=np.number).columns
    fig, ax = plt.subplots()
    if len(numeric_cols) > 0:
        # Use first numeric column for histogram
        col = numeric_cols[0]
        ax.hist(df[col].dropna(), bins=10, color='skyblue', edgecolor='black')
        ax.set_title(f"Histogram of '{col}'")
        ax.set_xlabel(col)
        ax.set_ylabel("Frequency")
    else:
        # If no numeric columns, show an empty figure with a message
        ax.text(0.5, 0.5, "No numeric columns to plot", horizontalalignment='center', 
                verticalalignment='center', fontsize=12, color='red')
        ax.set_axis_off()
    plt.tight_layout()
    return stats_df, fig

# Build the Gradio interface using Blocks and Tabs
with gr.Blocks() as demo:
    # Plot Generator Tab
    with gr.Tab("Plot Generator"):
        gr.Markdown("### Generate a Plot\nSelect a function type and number of points to generate a plot.")
        with gr.Row():
            num_points = gr.Slider(10, 500, value=100, step=10, label="Number of Points")
            plot_type = gr.Radio(["Sine", "Cosine", "Linear", "Quadratic", "Random"], 
                                 label="Function Type", value="Sine")
        generate_button = gr.Button("Generate Plot")
        plot_output = gr.Plot(label="Output Plot")
        generate_button.click(fn=generate_plot, inputs=[num_points, plot_type], outputs=plot_output)

    # Text Encryption Tab
    with gr.Tab("Text Encryption"):
        gr.Markdown("### Encrypt Text\nEnter a message to encrypt and decrypt using symmetric encryption (Fernet).")
        message_input = gr.Textbox(lines=2, placeholder="Enter text here...", label="Message")
        encrypt_button = gr.Button("Encrypt & Decrypt")
        with gr.Row():
            key_output = gr.Textbox(label="Encryption Key", interactive=False)
            encrypted_output = gr.Textbox(label="Encrypted Text", interactive=False)
            decrypted_output = gr.Textbox(label="Decrypted Text", interactive=False)
        # outputs order matches function return: key, encrypted, decrypted
        encrypt_button.click(fn=encrypt_text, inputs=message_input, 
                             outputs=[key_output, encrypted_output, decrypted_output])

    # CSV Explorer Tab
    with gr.Tab("CSV Explorer"):
        gr.Markdown("### CSV Explorer\nUpload a CSV file to see summary statistics and a histogram of the first numeric column.")
        file_input = gr.File(label="Upload CSV File (with header)")
        process_button = gr.Button("Process CSV")
        with gr.Row():
            stats_output = gr.Dataframe(label="Summary Statistics")
            hist_plot_output = gr.Plot(label="Histogram")
        process_button.click(fn=process_csv, inputs=file_input, outputs=[stats_output, hist_plot_output])

# Launch the app with command-line arguments for host and port
if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Gradio Demo Application")
    parser.add_argument(
        "--server_name", type=str, default="0.0.0.0",
        help="Address to bind the Gradio server"
    )
    parser.add_argument(
        "--server_port", type=int, default=7860,
        help="Port number to run the app"
    )
    parser.add_argument(
        "--share", action="store_true",
        help="Whether to create a publicly shareable link via Gradio"
    )
    args = parser.parse_args()

    demo.launch(
        server_name=args.server_name,
        server_port=args.server_port,
        share=args.share
    )


############
# main.py
import gradio as gr
import argparse

def greet(name: str) -> str:
    return f"Hello, {name}!"

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Minimal Gradio health-check app")
    parser.add_argument(
        "--server_name", type=str, default="0.0.0.0",
        help="host to serve on (0.0.0.0 for all interfaces)"
    )
    parser.add_argument(
        "--server_port", type=int, default=8080,
        help="port to serve on"
    )
    args = parser.parse_args()

    iface = gr.Interface(
        fn=greet,
        inputs=gr.Textbox(label="Your Name"),
        outputs=gr.Textbox(label="Greeting"),
        title="Health-Check Gradio App",
        description="Just enter your name and hit Submit"
    )
    # Launch on the host/port passed by your entrypoint script
    iface.launch(server_name=args.server_name, server_port=args.server_port)

#########
# main.py
import os
import gradio as gr

def greet(name: str) -> str:
    return f"Hello, {name}!"

# Read host and port from env, with sane defaults
HOST = os.environ.get("SERVER_NAME", "0.0.0.0")
PORT = int(os.environ.get("PORT", "8080"))

iface = gr.Interface(
    fn=greet,
    inputs=gr.Textbox(label="Your Name"),
    outputs=gr.Textbox(label="Greeting"),
    title="Health-Check Gradio App",
    description="Type your name and click Submit"
)

if __name__ == "__main__":
    # Launch on the host/port that ShinyProxy expects
    iface.launch(server_name=HOST, server_port=PORT)
