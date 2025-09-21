from opentelemetry import trace, metrics
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter

from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader

import time

# Configure OTLP endpoint (adjust if your collector is not on localhost:4317)
OTLP_ENDPOINT = "localhost:4317"

# Set up tracing
resource = Resource.create({"service.name": "test-otel-python"})
trace.set_tracer_provider(TracerProvider(resource=resource))
tracer = trace.get_tracer(__name__)
span_processor = BatchSpanProcessor(OTLPSpanExporter(endpoint=OTLP_ENDPOINT, insecure=True))
trace.get_tracer_provider().add_span_processor(span_processor)

# Set up metrics
metric_exporter = OTLPMetricExporter(endpoint=OTLP_ENDPOINT, insecure=True)
reader = PeriodicExportingMetricReader(metric_exporter, export_interval_millis=5000)
provider = MeterProvider(resource=resource, metric_readers=[reader])
metrics.set_meter_provider(provider)
meter = metrics.get_meter(__name__)

# Create a counter metric
counter = meter.create_counter(
    name="example_counter",
    description="An example counter",
    unit="1"
)

# Send a test trace and metric
with tracer.start_as_current_span("test-span"):
    print("Sending a test span and metric...")
    counter.add(1, {"env": "test"})
    time.sleep(1)

print("Done. Check your Grafana/Tempo/Prometheus/Loki dashboards.")
