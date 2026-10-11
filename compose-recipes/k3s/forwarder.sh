#!/bin/sh
# DNS forwarder (one-shot). Let pods resolve docker-compose service names
# (liferay, postgres, ...) so a CX reaches Liferay by name — no hostAliases, no
# pinned IPs, works across parallel workspaces.
#
# docker's embedded DNS (127.0.0.11) is a loopback reachable only inside a
# container's own netns; a pod can't reach it, and k3s rewrites CoreDNS's
# upstream away from loopback. Fix: run CoreDNS in the node's netns
# (hostNetwork), where 127.0.0.11 IS reachable, and forward the Corefile there.
#
# We share the k3s netns (network_mode: service:k3s), so the admin kubeconfig's
# https://127.0.0.1:6443 works as-is.
set -e
export KUBECONFIG=/var/lib/rancher/k3s/server/cred/admin.kubeconfig

until kubectl get deploy coredns -n kube-system >/dev/null 2>&1; do sleep 1; done

kubectl -n kube-system get cm coredns -o yaml > /tmp/coredns.yaml
sed -i 's#forward . /etc/resolv.conf#forward . 127.0.0.11#; /^[[:space:]]*loop[[:space:]]*$/d' /tmp/coredns.yaml
kubectl -n kube-system apply -f /tmp/coredns.yaml

kubectl -n kube-system patch deploy coredns --type merge \
	-p '{"spec":{"template":{"spec":{"hostNetwork":true,"dnsPolicy":"Default"}}}}'

kubectl -n kube-system rollout restart deploy/coredns
kubectl -n kube-system rollout status deploy/coredns --timeout=90s
echo "dns-forwarder: CoreDNS now resolves compose service names"