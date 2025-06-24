import SwiftUI

struct ZoomScrollView<Content: View>: UIViewRepresentable {
    var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.maximumZoomScale = 4.0
        scrollView.minimumZoomScale = 1.0
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.delegate = context.coordinator

        let host = UIHostingController(rootView: content)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = .clear
        scrollView.addSubview(host.view)
        context.coordinator.hostingController = host

        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: scrollView.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            host.view.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        if let host = context.coordinator.hostingController {
            host.rootView = content
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        var hostingController: UIHostingController<Content>?
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return hostingController?.view
        }
    }
}
