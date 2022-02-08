defmodule DomainNameOperator.Controller.V1.CloudflareDnsRecord do
  @moduledoc """
  DomainNameOperator: CloudflareDnsRecord CRD.

  ## Kubernetes CRD Spec

  By default all CRD specs are assumed from the module name, you can override them using attributes.

  ### Examples
  ```
  # Kubernetes API version of this CRD, defaults to value in module name
  @version "v2alpha1"

  # Kubernetes API group of this CRD, defaults to "domain-name-operator.example.com"
  @group "kewl.example.io"

  The scope of the CRD. Defaults to `:namespaced`
  @scope :cluster

  CRD names used by kubectl and the kubernetes API
  @names %{
    plural: "foos",
    singular: "foo",
    kind: "Foo",
    shortNames: ["f", "fo"]
  }
  ```

  ## Declare RBAC permissions used by this module

  RBAC rules can be declared using `@rule` attribute and generated using `mix bonny.manifest`

  This `@rule` attribute is cumulative, and can be declared once for each Kubernetes API Group.

  ### Examples

  ```
  @rule {apiGroup, resources_list, verbs_list}

  @rule {"", ["pods", "secrets"], ["*"]}
  @rule {"apiextensions.k8s.io", ["foo"], ["*"]}
  ```

  ## Add additional printer columns

  Kubectl uses server-side printing. Columns can be declared using `@additional_printer_columns` and generated using `mix bonny.manifest`

  [Additional Printer Columns docs](https://kubernetes.io/docs/tasks/access-kubernetes-api/custom-resources/custom-resource-definitions/#additional-printer-columns)

  ### Examples
  
  ```
  @additional_printer_columns [
    %{
      name: "test",
      type: "string",
      description: "test",
      JSONPath: ".spec.test"
    }
  ]
  ```
  
  """


  #
  # Example Payload:
  #   %{
  #     "apiVersion" => "domain-name-operator.tamx.org/v1",
  #     "kind" => "CloudflareDnsRecord",
  #     "metadata" => %{
  #       "annotations" => %{
  #         "kubectl.kubernetes.io/last-applied-configuration" => %{
  #           "apiVersion" => "hello-operator.example.com/v1",
  #           "kind" => "Greeting",
  #           "metadata" => %{"annotations" => %{}, "name" => "hello-server", "namespace" => "default"},
  #           "spec" => %{"greeting" => "Howdy"}
  #         }
  #       },
  #       "clusterName" => "",
  #       "creationTimestamp" => "2018-12-30T17:17:58Z",
  #       "generation" => 1,
  #       "name" => "some-service-dns-record",
  #       "namespace" => "default",
  #       "resourceVersion" => "1359609",
  #       "selfLink" => "/apis/hello-operator.example.com/v1/namespaces/default/greetings/hello-server",
  #       "uid" => "daa7e59b-0c56-11e9-bd27-025000000001"
  #     },
  #     "spec" => %{
  #       "namespace" => "malan-staging",
  #       "serviceName" => "Howdy",
  #       "hostName" => "malan-staging",
  #       "domain" => "ameelio.xyz",
  #       "zone_id" => "abcdefg"
  #     }
  #   }
  #

  use Bonny.Controller

  alias CloudflareApi.DnsRecord

  @group "domain-name-operator.tamx.org"
  @version "v1"

  @scope :cluster
  @names %{
    plural: "cloudflare_dns_records",
    singular: "cloudflarednsrecord",
    kind: "CloudflareDnsRecord",
    shortNames: ["dns"]
  }

  # @rule {"", ["pods", "configmap"], ["*"]}
  # @rule {"", ["secrets"], ["create"]}

  @rule {"", ["services"], ["*"]}

  @doc """
  Handles an `ADDED` event
  """
  @spec add(map()) :: :ok | :error
  @impl Bonny.Controller
  def add(%{} = cloudflarednsrecord) do
    IO.inspect(cloudflarednsrecord)

    # Parse the cloudflarednsrecord into a DNS record
    record = parse(cloudflarednsrecord)
    with {:ok, cf} <- CloudflareOps.add_or_update_record(record) do
      :ok
    else
      err -> :err
    end
  end

  @doc """
  Handles a `MODIFIED` event
  """
  @spec modify(map()) :: :ok | :error
  @impl Bonny.Controller
  def modify(%{} = cloudflarednsrecord) do
    IO.inspect(cloudflarednsrecord)

    # Parse the cloudflarednsrecord into a DNS record
    record = parse(cloudflarednsrecord)
    with {:ok, cf} <- CloudflareOps.add_or_update_record(record) do
      :ok
    else
      err -> :err
    end
  end

  @doc """
  Handles a `DELETED` event
  """
  @spec delete(map()) :: :ok | :error
  @impl Bonny.Controller
  def delete(%{} = cloudflarednsrecord) do
    IO.inspect(cloudflarednsrecord)

    # Parse the cloudflarednsrecord into a DNS record
    record = parse(cloudflarednsrecord)
    with {:ok, cf} <- CloudflareOps.delete_record(record) do
      :ok
    else
      err -> :err
    end
  end

  @doc """
  Called periodically for each existing CustomResource to allow for reconciliation.
  """
  @spec reconcile(map()) :: :ok | :error
  @impl Bonny.Controller
  def reconcile(%{} = cloudflarednsrecord) do
    IO.inspect(cloudflarednsrecord)

    # Parse the cloudflarednsrecord into a DNS record
    record = parse(cloudflarednsrecord)
    with {:ok, cf} <- CloudflareOps.add_or_update_record(record) do
      :ok
    else
      err -> :err
    end
  end

  #
  # Example Payload:
  #   %{
  #     "apiVersion" => "domain-name-operator.tamx.org/v1",
  #     "kind" => "CloudflareDnsRecord",
  #     "metadata" => %{
  #       "annotations" => %{
  #         "kubectl.kubernetes.io/last-applied-configuration" => %{
  #           "apiVersion" => "hello-operator.example.com/v1",
  #           "kind" => "Greeting",
  #           "metadata" => %{"annotations" => %{}, "name" => "hello-server", "namespace" => "default"},
  #           "spec" => %{"greeting" => "Howdy"}
  #         }
  #       },
  #       "clusterName" => "",
  #       "creationTimestamp" => "2018-12-30T17:17:58Z",
  #       "generation" => 1,
  #       "name" => "some-service-dns-record",
  #       "namespace" => "default",
  #       "resourceVersion" => "1359609",
  #       "selfLink" => "/apis/hello-operator.example.com/v1/namespaces/default/greetings/hello-server",
  #       "uid" => "daa7e59b-0c56-11e9-bd27-025000000001"
  #     },
  #     "spec" => %{
  #       "namespace" => "malan-staging",
  #       "serviceName" => "Howdy",
  #       "hostName" => "malan-staging",
  #       "domain" => "ameelio.xyz",
  #       "zone_id" => "abcdefg"
  #     }
  #   }
  #

  defp parse(%{"metadata" => %{"name" => _name, "namespace" => _ns}, "spec" => %{"namespace" => ns, "serviceName" => name, "hostName" => hostname, "domain" => domain, "zone_id" => zone_id}}) do
    %{
      "status" => %{
        "loadBalancer" => %{
          "ingress" => [
            %{"ip" => ip}
          ]
        }
      }
    } = get_service(ns, name)

    with {:ok, _} <- Iptools.is_ipv4(ip),
         {:ok, _} <- validate_hostname(hostname),
         {:ok, _} <- validate_domain(domain),
         {:ok, cfar} <- assemble_cf_a_record(zone_id, hostname, ip) do
      {:ok, cfar}
    else
      err -> {:error, err}
    end
  end

  defp assemble_cf_a_record(zone_id, hostname, ip) do
    cfar = %DnsRecord{
             zone_id: zone_id,
             hostname: hostname,
             #ip: List.first(service.status.loadBalancer.ingress).ip
             ip: ip
           }
    {:ok, cfar}
  end

  defp get_service(namespace, name) do
    svc = %{
      "apiVersion" => "v1",
      "kind" => "Service",
      "metadata" => %{
        "name" => name,
        "namespace" => namespace
      }
    }

    with {:ok, conn} <- K8s.Conn.from_service_account(),
         operation <- K8s.Client.get(svc),
         {:ok, result} <- K8s.Client.run(conn, operation) do
      {:ok, result}
    else
      {:error, err} -> {:error, err}
      err -> {:error, err}
    end
  end

  defp validate_hostname(hostname) do
    # TODO
  end

  defp validate_domain(domain) do
    # TODO
  end
end
