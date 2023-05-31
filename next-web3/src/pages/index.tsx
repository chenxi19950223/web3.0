import {Inter} from 'next/font/google'
import {Header, Layout, Services, Transactions, Welcome} from "@/components";

const inter = Inter({subsets: ['latin']})

function Home({}: any) {
    return (
        <Layout>
            <div className='gradient-bg-welcome'>
                <Header/>
                <Welcome/>
                <Services/>
            </div>

            <Transactions/>
        </Layout>
    )
}


export default Home;
