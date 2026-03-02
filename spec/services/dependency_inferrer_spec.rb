require "rails_helper"

RSpec.describe DependencyInferrer do
  let(:team) { create(:team) }
  let(:source_system) { create(:service_system, team: team, name: "OrderService") }
  let(:target_system) { create(:service_system, team: team, name: "PaymentService") }
  let(:source_repo) { create(:repository, service_system: source_system) }
  let(:target_repo) { create(:repository, service_system: target_system) }

  subject { described_class.new(source_repo) }

  before do
    allow(GraphService).to receive(:create_edge)
    allow(GraphService).to receive(:delete_edge)
  end

  describe "#infer!" do
    context "with api_client artifacts" do
      let(:file) { create(:codebase_file, repository: source_repo, path: "app/clients/payment_client.rb", content: "class PaymentClient\n  def charge(amount)\n    HTTP.post('https://payment-service.internal/charge')\n  end\nend") }

      before do
        target_system # ensure target system exists before inference
        create(:extracted_artifact, codebase_file: file, artifact_type: :api_client, name: "PaymentClient")
      end

      it "creates a dependency to the matching system" do
        expect { subject.infer! }.to change(SystemDependency, :count).by(1)

        dep = SystemDependency.last
        expect(dep.source_system).to eq(source_system)
        expect(dep.target_system).to eq(target_system)
        expect(dep.dependency_type).to eq("http_api")
      end

      it "marks dependencies as inferred" do
        subject.infer!
        dep = SystemDependency.last
        expect(dep.metadata["inferred"]).to be true
      end

      it "does not duplicate existing dependencies" do
        subject.infer!
        expect { subject.infer! }.not_to change(SystemDependency, :count)
      end
    end

    context "with queue publisher/consumer artifacts" do
      let(:source_file) { create(:codebase_file, repository: source_repo, path: "app/publishers/orders_publisher.rb") }
      let(:target_file) { create(:codebase_file, repository: target_repo, path: "app/consumers/orders_consumer.rb") }

      before do
        create(:extracted_artifact, codebase_file: source_file, artifact_type: :queue_publisher, name: "OrdersPublisher")
        create(:extracted_artifact, codebase_file: target_file, artifact_type: :queue_consumer, name: "OrdersConsumer")
      end

      it "creates a messaging dependency between systems" do
        expect { subject.infer! }.to change(SystemDependency, :count).by(1)

        dep = SystemDependency.last
        expect(dep.source_system).to eq(source_system)
        expect(dep.target_system).to eq(target_system)
        expect(dep.dependency_type).to eq("rabbitmq")
      end
    end

    context "with no matching artifacts" do
      it "creates no dependencies" do
        expect { subject.infer! }.not_to change(SystemDependency, :count)
      end
    end
  end
end
